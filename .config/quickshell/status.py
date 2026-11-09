"""Stream local system status as JSON lines; unavailable devices are omitted."""
import json
import shutil
import subprocess
import time
from pathlib import Path


def read(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return ""


def command(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=2)
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def cpu_times():
    values = list(map(int, read("/proc/stat").splitlines()[0].split()[1:9]))
    return sum(values), values[3] + values[4]


def collect(previous, elapsed):
    data = {}
    data["fullMixer"] = shutil.which("pavucontrol") is not None
    data["bluetoothManager"] = shutil.which("blueman-manager") is not None
    total, idle = cpu_times()
    delta = total - previous[0]
    data["cpu"] = round(100 * (1 - (idle - previous[1]) / delta)) if delta else 0
    memory = {}
    for line in read("/proc/meminfo").splitlines():
        key, value = line.split(":", 1)
        memory[key] = int(value.split()[0])
    data["memory"] = round(100 * (1 - memory["MemAvailable"] / memory["MemTotal"]))
    disk = shutil.disk_usage("/")
    data["disk"] = round(100 * disk.used / disk.total)
    data["diskHint"] = f"/ · {disk.free / 2**30:.1f} GiB free of {disk.total / 2**30:.1f} GiB"

    for hwmon in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        if read(hwmon / "name") in ("coretemp", "k10temp", "zenpower", "cpu_thermal"):
            value = read(hwmon / "temp1_input")
            if value:
                data["temperature"] = round(int(value) / 1000)
                break

    for supply in sorted(Path("/sys/class/power_supply").glob("*")):
        if read(supply / "type") != "Battery":
            continue
        capacity = read(supply / "capacity")
        if not capacity:
            continue
        data["battery"] = int(capacity)
        data["charging"] = read(supply / "status") in ("Charging", "Full")
        power = read(supply / "power_now")
        if power:
            data["power"] = round(int(power) / 1_000_000, 1)
        break

    for light in sorted(Path("/sys/class/backlight").glob("*")):
        maximum = read(light / "max_brightness")
        current = read(light / "brightness")
        if maximum and current and int(maximum):
            data["brightness"] = round(100 * int(current) / int(maximum))
            break

    network = command("nmcli", "-t", "--escape", "no", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device")
    data["network"] = "offline"
    counters = {}
    for line in network.splitlines():
        fields = line.split(":", 3)
        if len(fields) != 4:
            continue
        device, kind, state, connection = fields
        if state != "connected" or kind not in ("wifi", "ethernet"):
            continue
        data["network"] = kind
        data["networkHint"] = connection + " · " + device
        rx = read(f"/sys/class/net/{device}/statistics/rx_bytes")
        if rx:
            counters[device] = int(rx)
            old = elapsed[1].get(device)
            if old is not None:
                data["speed"] = max(0, round((int(rx) - old) / elapsed[0] / 1024))
        break
    return data, (total, idle), counters


if __name__ == "__main__":
    previous = cpu_times()
    counters = {}
    last = time.monotonic()
    while True:
        now = time.monotonic()
        try:
            data, previous, counters = collect(previous, (max(now - last, 0.1), counters))
            print(json.dumps(data), flush=True)
        except (OSError, ValueError, KeyError, IndexError) as error:
            # Keep the stream alive during transient device removal or suspend.
            import sys
            print(f"status: {error}", file=sys.stderr, flush=True)
        last = now
        time.sleep(2)
