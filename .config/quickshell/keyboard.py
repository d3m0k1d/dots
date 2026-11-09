"""Stream Hyprland keyboard state, never key presses. Accept only 'next' on stdin."""
import json
from functools import lru_cache
import os
import select
import socket
import sys
import time
from pathlib import Path
from xml.etree import ElementTree


def language_codes():
    """ISO 639-3/2 identifiers -> ISO 639-1 when one exists, otherwise ISO 639-3."""
    result = {}
    for path in (Path("/usr/share/iso-codes/json/iso_639-3.json"),
                 Path("/usr/share/iso-codes/json/iso_639-2.json")):
        try:
            document = json.loads(path.read_text())
            for records in document.values():
                if not isinstance(records, list):
                    continue
                for record in records:
                    if not isinstance(record, dict):
                        continue
                    label = record.get("alpha_2") or record.get("alpha_3")
                    if not label:
                        continue
                    for key in ("alpha_2", "alpha_3", "bibliographic"):
                        if record.get(key):
                            result[record[key]] = label.upper()
        except (OSError, ValueError, TypeError):
            continue
    return result


def registry_from_xml(root, codes):
    """Read layout and variant metadata instead of equating country with language."""
    result = {}

    def metadata(config, fallback):
        short = config.findtext("shortDescription", "").strip()
        languages = [node.text.strip() for node in config.findall("./languageList/iso639Id") if node.text]
        label = codes.get(short)
        if not label and languages:
            label = codes.get(languages[0], languages[0].upper())
        return {"label": label or short.upper() or fallback,
                "description": config.findtext("description", "").strip()}

    for layout in root.findall("./layoutList/layout"):
        config = layout.find("configItem")
        if config is None:
            continue
        name = config.findtext("name", "").strip()
        if not name:
            continue
        base = metadata(config, name.upper())
        result[(name, "")] = base
        for variant in layout.findall("./variantList/variant/configItem"):
            variant_name = variant.findtext("name", "").strip()
            if variant_name:
                result[(name, variant_name)] = metadata(variant, base["label"])
    return result


@lru_cache(maxsize=1)
def layout_registry():
    codes = language_codes()
    records = {}
    roots = [Path(os.environ.get("XKB_CONFIG_ROOT", "/usr/share/X11/xkb")),
             Path("/usr/share/X11/xkb"), Path("/usr/local/share/X11/xkb")]
    for directory in dict.fromkeys(roots):
        for name in ("evdev.xml", "evdev.extras.xml", "base.xml"):
            try:
                parsed = registry_from_xml(ElementTree.parse(directory / "rules" / name).getroot(), codes)
                for key, value in parsed.items():
                    records.setdefault(key, value)
            except (OSError, ElementTree.ParseError):
                continue
    descriptions = {record["description"].casefold(): record["label"] for record in records.values() if record["description"]}
    return records, descriptions


def layout_label(code, variant, title):
    records, descriptions = layout_registry()
    record = records.get((code, variant))
    if record:
        return record["label"]
    if title.casefold() in descriptions:
        return descriptions[title.casefold()]
    record = records.get((code, ""))
    return record["label"] if record else (code or "KB").upper()


def keyboard_state(devices):
    keyboards = devices.get("keyboards", [])
    keyboard = next((item for item in keyboards if item.get("main")), None)
    if keyboard is None:
        keyboard = next((item for item in keyboards if item.get("layout")), None)
    if not keyboard:
        return {"available": False}
    layouts = [value.strip() for value in keyboard.get("layout", "").split(",")]
    index = keyboard.get("active_layout_index")
    code = layouts[index] if isinstance(index, int) and 0 <= index < len(layouts) else ""
    variants = [value.strip() for value in keyboard.get("variant", "").split(",")]
    variant = variants[index] if isinstance(index, int) and 0 <= index < len(variants) else ""
    if "(" in code and code.endswith(")"):
        code, inline_variant = code[:-1].split("(", 1)
        variant = variant or inline_variant
    title = keyboard.get("active_keymap", "")
    return {
        "available": True,
        "keyboard": keyboard["name"],
        "label": layout_label(code, variant, title),
        "layout": title or code,
        "caps": keyboard.get("capsLock"),
    }


def request(path, command):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(1)
        client.connect(str(path))
        client.sendall(command.encode())
        chunks, size = [], 0
        while True:
            chunk = client.recv(65536)
            if not chunk:
                break
            size += len(chunk)
            if size > 1024 * 1024:
                raise ValueError("Hyprland response too large")
            chunks.append(chunk)
    return b"".join(chunks).decode()


def switch_layout(path, state):
    if not state.get("available"):
        raise ValueError("No active keyboard")
    name = state["keyboard"]
    # Hyprland uses normalized device names; never accept IPC command delimiters.
    if not name or any(char.isspace() for char in name) or any(char in name for char in ";\x00"):
        raise ValueError("Invalid keyboard name")
    response = request(path, f"switchxkblayout {name} next")
    if response.strip() != "ok":
        raise ValueError("Hyprland could not switch this keyboard's layout")


def socket_paths():
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if not signature or not runtime or "/" in signature:
        raise ValueError("Hyprland session unavailable")
    directory = Path(runtime) / "hypr" / signature
    return directory / ".socket.sock", directory / ".socket2.sock"


def stream():
    request_path, event_path = socket_paths()
    events = None
    try:
        events = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        events.settimeout(1)
        events.connect(str(event_path))
        events.setblocking(False)
    except OSError:
        if events:
            events.close()
        events = None

    previous, state = None, {"available": False}
    next_poll, event_buffer, input_buffer = 0, b"", b""
    try:
        while True:
            now = time.monotonic()
            if now >= next_poll:
                try:
                    state = keyboard_state(json.loads(request(request_path, "j/devices")))
                except (OSError, ValueError, KeyError, TypeError):
                    state = {"available": False, "error": "Keyboard state unavailable"}
                if state != previous:
                    print(json.dumps(state), flush=True)
                    previous = state
                # Caps Lock has no reliable Hyprland IPC event. Query state only;
                # no subprocesses, evdev access, input grabs or key logging.
                next_poll = time.monotonic() + 0.25
            readers = [sys.stdin.fileno()] + ([events] if events else [])
            ready, _, _ = select.select(readers, [], [], max(0, next_poll - time.monotonic()))
            if sys.stdin.fileno() in ready:
                data = os.read(sys.stdin.fileno(), 4096)
                if not data:
                    return
                input_buffer = (input_buffer + data)[-4096:]
                while b"\n" in input_buffer:
                    line, input_buffer = input_buffer.split(b"\n", 1)
                    if line != b"next":
                        continue
                    try:
                        # Re-read the main keyboard: it may have changed since polling.
                        state = keyboard_state(json.loads(request(request_path, "j/devices")))
                        switch_layout(request_path, state)
                        previous = None
                    except (OSError, ValueError, KeyError, TypeError):
                        print(json.dumps({**state, "error": "Could not switch keyboard layout"}), flush=True)
                    next_poll = 0
            if events and events in ready:
                data = events.recv(65536)
                if not data:
                    events.close()
                    events = None
                else:
                    event_buffer = (event_buffer + data)[-65536:]
                    while b"\n" in event_buffer:
                        line, event_buffer = event_buffer.split(b"\n", 1)
                        if line.startswith(b"activelayout>>"):
                            next_poll = 0
    finally:
        if events:
            events.close()


if __name__ == "__main__":
    try:
        stream()
    except (OSError, ValueError):
        print(json.dumps({"available": False, "error": "Keyboard monitor unavailable"}), flush=True)
