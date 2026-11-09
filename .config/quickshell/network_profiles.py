"""Edit NetworkManager profiles with nmcli; never activate implicitly."""
import ipaddress
import json
import os
import re
import subprocess
import sys
import uuid

FIELDS = [
    "connection.id", "connection.uuid", "connection.type", "connection.interface-name",
    "connection.autoconnect",
] + [f"{family}.{key}" for family in ("ipv4", "ipv6") for key in (
    "method", "addresses", "gateway", "dns", "dns-search", "ignore-auto-dns",
    "never-default", "route-metric", "routes",
)]
MTU_FIELDS = {"802-3-ethernet.mtu", "802-11-wireless.mtu"}
EDITABLE = (set(FIELDS) | MTU_FIELDS) - {"connection.uuid", "connection.type"}
METHODS = {
    "ipv4": {"auto", "manual", "disabled", "link-local", "shared"},
    "ipv6": {"auto", "dhcp", "manual", "disabled", "ignore", "link-local", "shared"},
}


def nmcli(*args):
    result = subprocess.run(
        ["nmcli", "--wait", "30", *args], capture_output=True, text=True, timeout=40,
        env={**os.environ, "LC_ALL": "C"},
    )
    if result.returncode:
        raise ValueError(result.stderr.strip() or result.stdout.strip() or "NetworkManager request failed")
    return result.stdout.strip()


def split_fields(line):
    """Decode nmcli terse escaping (including colons inside names/IPv6)."""
    result, buffer, escaped = [], [], False
    for char in line:
        if escaped:
            buffer.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            result.append("".join(buffer))
            buffer = []
        else:
            buffer.append(char)
    if escaped:
        buffer.append("\\")
    result.append("".join(buffer))
    return result


def checked_uuid(value):
    return str(uuid.UUID(value))


def load(profile_uuid):
    output = nmcli("-t", "--escape", "yes", "-f", ",".join(FIELDS), "connection", "show", "uuid", checked_uuid(profile_uuid))
    values = {}
    for line in output.splitlines():
        parts = split_fields(line)
        if len(parts) >= 2:
            values[parts[0]] = ":".join(parts[1:])
    mtu_key = values.get("connection.type", "") + ".mtu"
    if mtu_key in MTU_FIELDS:
        values[mtu_key] = nmcli("-g", mtu_key, "connection", "show", "uuid", profile_uuid)
    return values


def entries(value):
    return [item for item in re.split(r"[,\s]+", value.strip()) if item]


def validate(values, changed=None):
    changed = set(values) if changed is None else set(changed)
    if "connection.id" in changed and not values.get("connection.id", "").strip():
        raise ValueError("Profile name cannot be empty")
    if "connection.autoconnect" in changed and values.get("connection.autoconnect") not in ("yes", "no"):
        raise ValueError("Autoconnect must be yes or no")
    for key in MTU_FIELDS.intersection(changed):
        mtu = values[key]
        if mtu != "auto" and not 0 <= int(mtu) <= 65535:
            raise ValueError("MTU must be auto, 0 or a value up to 65535")
    for family, version in (("ipv4", 4), ("ipv6", 6)):
        method = values.get(family + ".method")
        if family + ".method" in changed and method not in METHODS[family]:
            raise ValueError(f"Unsupported {family} method: {method}")
        addresses = entries(values.get(family + ".addresses", ""))
        if changed.intersection({family + ".method", family + ".addresses"}) and method == "manual" and not addresses:
            raise ValueError(f"{family}: static configuration requires an address/prefix")
        for address in addresses if family + ".addresses" in changed else []:
            if "/" not in address or ipaddress.ip_interface(address).version != version:
                raise ValueError(f"{family}: use address/prefix notation")
        for address in entries(values.get(family + ".dns", "")) if family + ".dns" in changed else []:
            if ipaddress.ip_address(address).version != version:
                raise ValueError(f"{family}: incorrect DNS address family")
        gateway = values.get(family + ".gateway", "").strip()
        if family + ".gateway" in changed and gateway and ipaddress.ip_address(gateway).version != version:
            raise ValueError(f"{family}: incorrect gateway address family")
        for key in ("ignore-auto-dns", "never-default"):
            if f"{family}.{key}" in changed and values.get(f"{family}.{key}") not in ("yes", "no"):
                raise ValueError(f"{family}.{key}: expected yes or no")
        if family + ".route-metric" in changed:
            metric = int(values.get(family + ".route-metric", "-1"))
            if not -1 <= metric <= 4294967295:
                raise ValueError(f"{family}: invalid route metric")


def save(payload):
    original = payload["original"]
    changes = payload["changes"]
    profile_uuid = checked_uuid(original["connection.uuid"])
    if not set(changes) <= EDITABLE or not all(isinstance(value, str) for value in changes.values()):
        raise ValueError("Unsupported profile property")
    current = load(profile_uuid)
    if any(current.get(key, "") != original.get(key, "") for key in set(current) | set(original)):
        raise ValueError("Profile changed elsewhere. Reload it before saving.")
    merged = {**current, **changes}
    validate(merged, changes)
    args = []
    for key, value in changes.items():
        if key.endswith((".addresses", ".dns")):
            value = ",".join(entries(value))
        args.extend([key, value])
    if args:
        # One modify operation: validation failure must not leave half a profile.
        nmcli("connection", "modify", "uuid", profile_uuid, *args)
    return {"profile": load(profile_uuid), "message": "Saved. The running connection was not restarted."}


def main(action, payload):
    if action == "list":
        output = nmcli("-t", "--escape", "yes", "-f", "UUID,NAME,TYPE,DEVICE", "connection", "show")
        profiles = []
        for line in output.splitlines():
            parts = split_fields(line)
            if len(parts) == 4:
                profiles.append(dict(zip(("uuid", "name", "type", "device"), parts)))
        return {"profiles": profiles}
    if action == "load":
        return {"profile": load(payload["uuid"])}
    if action == "save":
        return save(payload)
    if action == "clone":
        name = payload["name"].strip()
        if not name or "\n" in name:
            raise ValueError("Enter a profile name")
        nmcli("connection", "clone", "uuid", checked_uuid(payload["uuid"]), name)
        return {"message": "Profile duplicated. Select the copy to edit it."}
    if action == "create":
        name = payload["name"].strip()
        interface = payload.get("interface", "").strip() or "*"
        if not name or "\n" in name:
            raise ValueError("Enter a profile name")
        if interface != "*" and not re.fullmatch(r"[a-zA-Z0-9_.:@-]{1,15}", interface):
            raise ValueError("Invalid interface name")
        profile_uuid = str(uuid.uuid4())
        nmcli("connection", "add", "type", "ethernet", "ifname", interface, "con-name", name,
              "connection.uuid", profile_uuid, "connection.autoconnect", "no")
        return {"profile": load(profile_uuid), "message": "Ethernet profile created. Autoconnect is off; nothing was activated."}
    if action == "activate":
        nmcli("connection", "up", "uuid", checked_uuid(payload["uuid"]))
        return {"message": "Profile activated."}
    raise ValueError("Unknown operation")


if __name__ == "__main__":
    try:
        print(json.dumps({"ok": True, **main(sys.argv[1], json.loads(sys.argv[2]))}))
    except (ValueError, KeyError, IndexError, TypeError, OSError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        sys.exit(1)
