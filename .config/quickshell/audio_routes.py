"""Route existing PulseAudio-compatible streams; never alter global defaults."""
import json
import os
import subprocess
import sys


def pactl(*args):
    result = subprocess.run(["pactl", *args], capture_output=True, text=True, timeout=5,
                            env={**os.environ, "LC_ALL": "C"})
    if result.returncode:
        raise ValueError(result.stderr.strip() or "PulseAudio-compatible server unavailable")
    return result.stdout


def snapshot():
    devices, streams = {}, {}
    for direction, device_type, stream_type, target_key in (
            ("output", "sinks", "sink-inputs", "sink"),
            ("input", "sources", "source-outputs", "source")):
        raw_devices = json.loads(pactl("-f", "json", "list", device_type))
        devices[direction] = [{
            "index": item["index"], "name": item["name"],
            "description": item.get("description") or item["name"],
            "serial": str(item.get("properties", {}).get("object.serial", "")),
        } for item in raw_devices]
        targets = {item["index"]: item for item in devices[direction]}
        for item in json.loads(pactl("-f", "json", "list", stream_type)):
            properties = item.get("properties", {})
            node_id = properties.get("object.id")
            serial = properties.get("object.serial")
            if node_id is None or serial is None:
                continue
            target = targets.get(item.get(target_key), {})
            streams[str(node_id)] = {
                "index": item["index"], "serial": str(serial), "direction": direction,
                "target": item.get(target_key), "targetName": target.get("description", "Unavailable device"),
            }
    return {"devices": devices, "streams": streams}


def move(payload):
    # Re-read before acting: menus may be stale after app exit or hot-unplug.
    current = snapshot()
    stream = current["streams"].get(str(payload["nodeId"]))
    if not stream or stream["serial"] != str(payload["streamSerial"]):
        raise ValueError("Audio stream changed or closed. Refresh and try again.")
    target = next((item for item in current["devices"][stream["direction"]]
                   if item["name"] == payload["targetName"] and item["serial"] == str(payload["targetSerial"])), None)
    if not target or not target["serial"]:
        raise ValueError("Audio device changed or disconnected. Refresh and try again.")
    if stream["target"] != target["index"]:
        operation = "move-sink-input" if stream["direction"] == "output" else "move-source-output"
        pactl(operation, str(stream["index"]), target["name"])
    return {"snapshot": snapshot(), "message": "Stream routed to " + target["description"]}


def main(action, payload):
    if action == "list":
        return {"snapshot": snapshot()}
    if action == "move":
        return move(payload)
    raise ValueError("Unknown audio routing operation")


if __name__ == "__main__":
    try:
        print(json.dumps({"ok": True, **main(sys.argv[1], json.loads(sys.argv[2]))}))
    except (OSError, ValueError, KeyError, IndexError, TypeError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        sys.exit(1)
