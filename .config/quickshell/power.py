"""Explicit session/power actions. Never bypass logind inhibitors."""
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=20)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Action failed")
    return result.stdout.strip()


def lock_session():
    if not shutil.which("hyprlock"):
        raise RuntimeError("Install hyprlock to lock the session")
    # hyprlock remains alive until unlocked; do not wait for it to exit.
    process = subprocess.Popen(["hyprlock", "--grace", "0", "--no-fade-in"], stdin=subprocess.DEVNULL,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               start_new_session=True)
    time.sleep(0.2)
    if process.poll() is not None and process.returncode != 0:
        raise RuntimeError("hyprlock failed to start. Check its configuration.")


def bus_call(service, path, interface, method, *args):
    response = run("busctl", "--user", "--json=short", "--auto-start=no", "--timeout=2",
                   "call", service, path, interface, method, *args)
    return json.loads(response)["data"][0]


def sleep_guard_owner():
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        raise RuntimeError("Hyprland session unavailable; suspend cancelled")
    try:
        owner = bus_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                         "GetNameOwner", "s", "org.freedesktop.ScreenSaver")
        pid = bus_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                       "GetConnectionUnixProcessID", "s", owner)
        if not isinstance(pid, int) or pid <= 0:
            raise ValueError("Invalid guard process")
        process = Path("/proc") / str(pid)
        environment = dict(item.split(b"=", 1) for item in (process / "environ").read_bytes().split(b"\0") if b"=" in item)
        if (process.stat().st_uid != os.getuid() or (process / "comm").read_text().strip() != "hypridle"
                or environment.get(b"HYPRLAND_INSTANCE_SIGNATURE") != signature.encode()):
            raise ValueError("The guard does not belong to this Hyprland session")
        return owner
    except (OSError, RuntimeError, ValueError, KeyError, IndexError, TypeError, subprocess.TimeoutExpired) as error:
        raise RuntimeError("Start hypridle 0.1.8+ in this Hyprland session. Suspend cancelled: no verified lock monitor.") from error


def guard_locked(owner):
    # hypridle's GetActive follows hyprland-lock-notify-v1, not a running PID
    # or logind's potentially stale LockedHint. Pin calls to the verified owner.
    return bus_call(owner, "/org/freedesktop/ScreenSaver", "org.freedesktop.ScreenSaver", "GetActive") is True


def prepare_suspend(timeout=10):
    owner = sleep_guard_owner()
    session = os.environ.get("XDG_SESSION_ID")
    if not session:
        raise RuntimeError("Session ID unavailable; suspend cancelled")
    if guard_locked(owner):
        return
    run("loginctl", "lock-session", session)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if guard_locked(owner):
            return
        time.sleep(0.1)
    raise RuntimeError("The compositor did not confirm a locked session. Suspend cancelled; check hyprlock / hypridle.")


def execute(action, mode):
    if action not in {"lock", "suspend", "logout", "reboot", "poweroff"}:
        raise ValueError("Unknown power action")
    if mode not in {"lua", "legacy"}:
        raise ValueError("Unknown Hyprland mode")
    if action == "lock":
        lock_session()
    elif action == "suspend":
        prepare_suspend()
        run("systemctl", "--no-ask-password", "suspend")
    elif action == "logout":
        if mode == "lua":
            run("hyprctl", "eval", "hl.dispatch(hl.dsp.exit())")
        else:
            run("hyprctl", "dispatch", "exit")
    else:
        run("systemctl", "--no-ask-password", action)


if __name__ == "__main__":
    try:
        execute(sys.argv[1], sys.argv[2])
        print(json.dumps({"ok": True}))
    except (ValueError, RuntimeError, OSError, KeyError, TypeError, IndexError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        sys.exit(1)
