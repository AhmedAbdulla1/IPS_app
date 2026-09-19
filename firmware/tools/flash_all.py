#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
flash_all.py - Flashes one ready ESP-IDF build onto multiple ESP32 boards
connected on different COM ports at the same time (parallel).

Basic usage (after running idf.py build once):
    python flash_all.py --project E:\\IPS_app\\firmware\\IPS_Mesh_Node

Auto-detects connected boards (looks for common USB-UART chips like
CP210x / CH340 / FTDI), shows them to you, and asks for confirmation
before starting. To target specific ports instead:
    python flash_all.py --project E:\\IPS_app\\firmware\\IPS_Mesh_Node --ports COM8,COM9,COM12

Other options:
    --baud 460800   Flash speed (default 460800, lower it if it fails)
    --erase         Only erase_flash (instead of flashing code) - useful
                     before flashing a brand-new board, or when old NVS
                     data is causing provisioning issues.
    --yes           Skip the confirmation prompt (useful when calling
                     this script from another script)

Important: run this script with the same Python that ESP-IDF uses (the
one that has esptool installed) - i.e. from the same terminal where
`idf.py build` works (after running export.bat / activating the venv).
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime
from pathlib import Path

try:
    import serial.tools.list_ports as list_ports
except ImportError:
    print("Missing pyserial. Run: pip install pyserial")
    sys.exit(1)


def find_esp_python():
    """Finds the ESP-IDF Python (the one with esptool installed) instead of
    relying on whatever "python" happens to be first in PATH.
    IDF_PYTHON_ENV_PATH is set automatically when you run ESP-IDF's
    export.bat/export.ps1, so it's the most reliable source. Falls back
    to searching common Espressif installation paths before sys.executable."""
    idf_python_env = os.environ.get("IDF_PYTHON_ENV_PATH")
    if idf_python_env:
        candidate = Path(idf_python_env) / "Scripts" / "python.exe"
        if candidate.exists():
            return str(candidate)

    import glob
    search_patterns = [
        "C:/Espressif/tools/python/*/venv/Scripts/python.exe",
        "C:/Espressif/python_env/*/Scripts/python.exe",
        str(Path.home() / ".espressif/python_env/*/Scripts/python.exe"),
    ]
    for pattern in search_patterns:
        matches = glob.glob(pattern)
        if matches:
            matches.sort(reverse=True)
            return matches[0]

    return sys.executable


PYTHON_EXE = find_esp_python()


def check_esptool_available():
    """Confirms esptool actually works before starting to flash multiple
    ports in parallel - better than every thread failing for the same
    reason at once."""
    try:
        result = subprocess.run(
            [PYTHON_EXE, "-m", "esptool", "version"],
            capture_output=True, text=True, timeout=15,
        )
        return result.returncode == 0
    except Exception:  # noqa: BLE001
        return False


# Keywords that usually indicate a port has a common USB-UART chip used
# on ESP32 boards (CP2102, CH340/CH9102, FTDI...).
ESP_PORT_HINTS = (
    "cp210", "ch340", "ch9102", "ftdi", "usb-serial", "usb serial",
    "silicon labs", "usb2.0-serial", "uart",
)


def find_esp_ports():
    """Returns every COM port that looks like an ESP32 (based on its
    description/manufacturer string)."""
    ports = []
    for p in list_ports.comports():
        haystack = f"{p.description or ''} {p.manufacturer or ''}".lower()
        if any(hint in haystack for hint in ESP_PORT_HINTS):
            ports.append(p.device)
    return sorted(ports)


def load_flasher_args(project_dir: Path):
    args_file = project_dir / "build" / "flasher_args.json"
    if not args_file.exists():
        print(f"No build found. Run this first:\n   cd {project_dir}\n   idf.py build")
        sys.exit(1)
    with open(args_file, "r", encoding="utf-8") as f:
        return json.load(f)


def build_flash_cmd(flasher_args, project_dir: Path, port: str, baud: str):
    chip = flasher_args.get("extra_esptool_args", {}).get("chip", "esp32")
    write_flash_args = flasher_args["write_flash_args"]
    flash_files = flasher_args["flash_files"]

    cmd = [
        PYTHON_EXE, "-m", "esptool",
        "--chip", chip,
        "--port", port,
        "--baud", str(baud),
        "write_flash",
    ] + write_flash_args

    for offset, rel_path in flash_files.items():
        cmd += [offset, str(project_dir / "build" / rel_path)]

    return cmd


def build_erase_cmd(flasher_args, port: str, baud: str):
    chip = flasher_args.get("extra_esptool_args", {}).get("chip", "esp32")
    return [
        PYTHON_EXE, "-m", "esptool",
        "--chip", chip,
        "--port", port,
        "--baud", str(baud),
        "erase_flash",
    ]


def flash_one(port, cmd, results, lock):
    start = time.time()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        ok = proc.returncode == 0
        output = (proc.stdout or "") + "\n" + (proc.stderr or "")
    except Exception as e:  # noqa: BLE001 - catch anything and report it, don't kill other threads
        ok = False
        output = f"Exception while running esptool: {e}"

    elapsed = time.time() - start

    with lock:
        status = "OK" if ok else "FAILED"
        print(f"[{port}] {status}  ({elapsed:.1f}s)")
        tail = output.strip().splitlines()[-15:]
        print(f"    last lines from {port}:")
        for line in tail:
            print(f"      {line}")

    results[port] = ok


def main():
    if not check_esptool_available():
        print("Could not find esptool with this Python:", PYTHON_EXE)
        print(
            "   Likely cause: you're running this script from a plain "
            "terminal, not the activated ESP-IDF terminal (the one with "
            "(venv) shown at the start of the prompt).\n"
            "   Run export.bat or export.ps1 from your ESP-IDF install "
            "folder first, then run this script again from that same terminal."
        )
        sys.exit(1)

    parser = argparse.ArgumentParser(description="Flash one build onto multiple ESP32 boards in parallel")
    parser.add_argument("--project", required=True, help="Path to the ESP-IDF project (must have a build/ folder)")
    parser.add_argument("--ports", default=None, help="Comma-separated COM ports, e.g. COM8,COM9,COM12")
    parser.add_argument("--baud", default="460800", help="Flash speed (default 460800)")
    parser.add_argument("--erase", action="store_true", help="Only erase_flash, don't flash code")
    parser.add_argument("--yes", action="store_true", help="Skip the confirmation prompt")
    args = parser.parse_args()

    project_dir = Path(args.project)

    if args.ports:
        ports = [p.strip() for p in args.ports.split(",") if p.strip()]
    else:
        ports = find_esp_ports()

    if not ports:
        print("No ESP32 ports auto-detected.")
        print("   Try specifying ports manually: --ports COM8,COM9,COM12")
        print("   Or make sure the driver (CP210x/CH340) is installed.")
        sys.exit(1)

    action = "Erase" if args.erase else "Flash code from"
    print(f"Found {len(ports)} port(s): {', '.join(ports)}")
    print(f"Action: {action} {project_dir if not args.erase else ''}")

    if not args.yes:
        confirm = input("Continue on all these ports? (y/n): ").strip().lower()
        if confirm != "y":
            print("Cancelled.")
            sys.exit(0)

    flasher_args = None if args.erase else load_flasher_args(project_dir)

    threads = []
    results = {}
    lock = threading.Lock()

    for port in ports:
        if args.erase:
            cmd = build_erase_cmd(flasher_args or {"extra_esptool_args": {"chip": "esp32"}}, port, args.baud)
        else:
            cmd = build_flash_cmd(flasher_args, project_dir, port, args.baud)
        t = threading.Thread(target=flash_one, args=(port, cmd, results, lock))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    print("\n=== Summary ===")
    for port in ports:
        ok = results.get(port, False)
        print(f"  {port}: {'OK' if ok else 'FAILED'}")

    fail_count = sum(1 for ok in results.values() if not ok)
    if fail_count:
        print(f"\n{fail_count} of {len(ports)} port(s) failed. Scroll up to see each port's log tail.")
        sys.exit(1)

    print(f"\nAll {len(ports)} port(s) flashed successfully!")


if __name__ == "__main__":
    main()
