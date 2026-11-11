"""Read and explicitly-confirm Tailscale/Headscale actions."""
import json
import os
import shutil
import subprocess
import sys


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=10,
                            env={**os.environ, "LC_ALL": "C"})
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "tailscale command failed")
    return result.stdout


def privileged(*args):
    try:
        return run("tailscale", *args)
    except RuntimeError:
        pass
    if not shutil.which("sudo"):
        raise RuntimeError("sudo is required for Tailscale control")
    return run("sudo", "-n", "--", "tailscale", *args)


def preferences():
    try:
        return json.loads(run("tailscale", "debug", "prefs"))
    except (OSError, RuntimeError, ValueError, TypeError, json.JSONDecodeError, subprocess.TimeoutExpired):
        return {}


def snapshot():
    if not shutil.which("tailscale"):
        return {"available": False, "error": "tailscale is not installed", "state": "missing"}
    try:
        raw = run("tailscale", "status", "--json")
        data = json.loads(raw)
        self_node = data.get("Self") or {}
        peers = []
        for node in (data.get("Peer") or {}).values():
            ips = node.get("TailscaleIPs", [])
            peers.append({
                "name": node.get("HostName") or node.get("DNSName") or node.get("ID", "peer"),
                "dns": node.get("DNSName", "").rstrip("."),
                "ips": ips,
                "online": bool(node.get("Online")),
                "os": node.get("OS", ""),
                "exitNode": bool(node.get("ExitNode")),
                "lastSeen": node.get("LastSeen", ""),
            })
        peers.sort(key=lambda item: (not item["online"], item["name"].casefold()))
        backend = data.get("BackendState", "Unknown")
        prefs = preferences()
        advertised_routes = prefs.get("AdvertiseRoutes") or []
        if isinstance(advertised_routes, str):
            advertised_routes = [advertised_routes] if advertised_routes else []
        return {
            "available": True, "state": backend, "hostname": self_node.get("HostName", ""),
            "dnsName": self_node.get("DNSName", "").rstrip("."),
            "ips": self_node.get("TailscaleIPs", []), "peers": peers,
            "tailnet": (data.get("CurrentTailnet") or {}).get("Name", ""),
            "loginUrl": data.get("AuthURL", ""),
            "acceptDns": bool(prefs.get("CorpDNS", True)),
            "acceptRoutes": bool(prefs.get("RouteAll", False)),
            "advertiseRoutes": advertised_routes,
        }
    except (OSError, RuntimeError, ValueError, TypeError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        return {"available": True, "state": "error", "peers": [], "error": str(error)}


def action(name, payload):
    if name == "set":
        args = []
        if "acceptDns" in payload:
            args += ["--accept-dns=" + ("true" if bool(payload["acceptDns"]) else "false")]
        if "acceptRoutes" in payload:
            args += ["--accept-routes=" + ("true" if bool(payload["acceptRoutes"]) else "false")]
        if "advertiseRoutes" in payload:
            routes = str(payload["advertiseRoutes"]).strip()
            args += ["--advertise-routes", routes]
        if not args:
            raise ValueError("No Tailscale setting was provided")
        return {"message": "Tailscale settings updated", "output": privileged("set", *args)}
    if name == "up":
        server = str(payload.get("server", "")).strip()
        if server and not (server.startswith("https://") or server.startswith("http://")):
            raise ValueError("Headscale server must be an http(s) URL")
        args = ["up", "--accept-dns=true"]
        if server:
            args += ["--login-server", server]
        auth_key = str(payload.get("authKey", "")).strip()
        if auth_key:
            args += ["--auth-key", auth_key]
        return {"message": "Tailscale connection requested", "output": privileged(*args)}
    if name == "down":
        return {"message": "Tailscale stopped", "output": privileged("down")}
    if name == "logout":
        return {"message": "Tailscale logged out", "output": privileged("logout")}
    raise ValueError("Unknown Tailscale operation")


if __name__ == "__main__":
    try:
        payload = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
        result = snapshot() if len(sys.argv) < 2 or sys.argv[1] == "status" else action(sys.argv[1], payload)
        print(json.dumps({"ok": True, **result}))
    except (OSError, RuntimeError, ValueError, KeyError, TypeError, IndexError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        sys.exit(1)
