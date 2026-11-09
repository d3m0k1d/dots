"""Manage saved NetworkManager VPN/WireGuard profiles, not external tunnels."""
import json
import re
import shutil
import subprocess
import sys

from network_profiles import checked_uuid, nmcli, split_fields

VPN_TYPES = {"vpn", "wireguard"}


def rows(output, columns):
    result = []
    for line in output.splitlines():
        values = split_fields(line)
        if len(values) == len(columns):
            result.append(dict(zip(columns, values)))
    return result


def details(profile_uuid):
    fields = "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS"
    output = nmcli("-t", "--escape", "yes", "-f", fields, "connection", "show", "uuid", profile_uuid)
    result = {}
    for line in output.splitlines():
        parts = split_fields(line)
        if len(parts) < 2:
            continue
        key = re.sub(r"\[\d+\]$", "", parts[0])
        value = ":".join(parts[1:])
        if value:
            result.setdefault(key, []).append(value)
    return result


def snapshot():
    profiles = rows(nmcli("-t", "--escape", "yes", "-f", "UUID,NAME,TYPE,DEVICE", "connection", "show"),
                    ("uuid", "name", "type", "device"))
    active = rows(nmcli("-t", "--escape", "yes", "-f", "UUID,STATE,DEVICE", "connection", "show", "--active"),
                  ("uuid", "state", "device"))
    active_by_uuid = {item["uuid"]: item for item in active}
    result = []
    for profile in profiles:
        if profile["type"] not in VPN_TYPES:
            continue
        state = active_by_uuid.get(profile["uuid"], {}).get("state", "disconnected")
        profile.update(state=state, connected=state == "activated", details={})
        if profile["connected"]:
            profile["details"] = details(checked_uuid(profile["uuid"]))
        result.append(profile)
    result.sort(key=lambda item: (not item["connected"], item["name"].casefold()))
    managed_devices = {item["device"] for item in result if item["device"]}
    devices = rows(nmcli("-t", "--escape", "yes", "-f", "DEVICE,TYPE,STATE", "device"),
                   ("device", "type", "state"))
    other_tunnels = [item for item in devices if item["type"] in {"tun", "wireguard", "ip-tunnel"}
                     and item["device"] not in managed_devices]
    return {"profiles": result, "otherTunnels": other_tunnels,
            "editorAvailable": shutil.which("nm-connection-editor") is not None}


def main(action, payload):
    if action == "list":
        return snapshot()
    if action not in {"up", "down"}:
        raise ValueError("Unknown VPN operation")
    profile_uuid = checked_uuid(payload["uuid"])
    kind = nmcli("-g", "connection.type", "connection", "show", "uuid", profile_uuid)
    if kind not in VPN_TYPES:
        raise ValueError("This is not a saved VPN/WireGuard profile. External tunnels are read-only here.")
    nmcli("connection", action, "uuid", profile_uuid)
    return {"message": "Profile activated. Tunnel reachability / WireGuard handshake is not verified." if action == "up" else "VPN disconnected."}


if __name__ == "__main__":
    try:
        print(json.dumps({"ok": True, **main(sys.argv[1], json.loads(sys.argv[2]))}))
    except (ValueError, KeyError, IndexError, TypeError, OSError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        sys.exit(1)
