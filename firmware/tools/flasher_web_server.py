#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
flasher_web_server.py - High-Performance Web UI Server for Parallel ESP32 Flashing
with Interactive Serial Terminal for Each Port.

Pure Python standard library implementation: Zero extra pip dependencies required!
"""

import json
import os
import re
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs

try:
    import serial
    import serial.tools.list_ports as list_ports
except ImportError:
    print("WARNING: pyserial not installed. Serial communication will be limited.")
    serial = None
    list_ports = None

# Base directories
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
FIRMWARE_DIR = PROJECT_ROOT
UI_DIR = SCRIPT_DIR / "flasher-ui"

# Find ESP-IDF Python and esptool
def find_esp_tools():
    direct_candidates = [
        "C:/Espressif/tools/python/v5.5.5/venv/Scripts/python.exe",
        "C:/Espressif/tools/python/v5.5.5/venv/Scripts/esptool.exe",
    ]
    python_exe = sys.executable
    esptool_exe = None

    if Path(direct_candidates[0]).exists():
        python_exe = direct_candidates[0]

    if Path(direct_candidates[1]).exists():
        esptool_exe = direct_candidates[1]

    idf_env = os.environ.get("IDF_PYTHON_ENV_PATH")
    if idf_env:
        p = Path(idf_env) / "Scripts" / "python.exe"
        e = Path(idf_env) / "Scripts" / "esptool.exe"
        if p.exists():
            python_exe = str(p)
        if e.exists():
            esptool_exe = str(e)

    return python_exe, esptool_exe

PYTHON_EXE, ESPTOOL_EXE = find_esp_tools()

ESP_PORT_HINTS = (
    "cp210", "ch340", "ch9102", "ftdi", "usb-serial", "usb serial",
    "silicon labs", "usb2.0-serial", "uart", "espressif", "jtag"
)

# Serial Terminal Manager for Interactive Per-Port Consoles
class SerialTerminalManager:
    def __init__(self):
        self.lock = threading.Lock()
        self.sessions = {}  # port -> {ser, baud, running, buffer, next_id}

    def open_port(self, port, baud=115200):
        if not serial:
            return False, "pyserial library is not installed"
        self.close_port(port)
        with self.lock:
            try:
                ser = serial.Serial()
                ser.port = port
                ser.baudrate = baud
                ser.dtr = False
                ser.rts = False
                ser.timeout = 0.1
                ser.open()
            except Exception as e:
                return False, str(e)

            session = {
                "serial": ser,
                "baud": baud,
                "running": True,
                "buffer": [],  # list of (id, text)
                "next_id": 1,
            }
            self.sessions[port] = session

            t = threading.Thread(
                target=self._reader_thread,
                args=(port, session),
                daemon=True
            )
            session["thread"] = t
            t.start()
            return True, "Connected"

    def _reader_thread(self, port, session):
        ser = session["serial"]
        line_buf = ""
        while session["running"]:
            try:
                data = ser.read(ser.in_waiting or 1)
                if data:
                    text = data.decode("utf-8", errors="replace")
                    with self.lock:
                        for ch in text:
                            if ch == "\n":
                                session["buffer"].append((session["next_id"], line_buf.strip("\r")))
                                session["next_id"] += 1
                                if len(session["buffer"]) > 500:
                                    session["buffer"].pop(0)
                                line_buf = ""
                            else:
                                line_buf += ch
                else:
                    time.sleep(0.015)
            except Exception:
                break
        session["running"] = False

    def poll_lines(self, port, since_id=0):
        with self.lock:
            session = self.sessions.get(port)
            if not session:
                return {"connected": False, "lines": [], "last_id": since_id}
            
            new_lines = [
                {"id": item[0], "text": item[1]}
                for item in session["buffer"]
                if item[0] > since_id
            ]
            last_id = session["buffer"][-1][0] if session["buffer"] else since_id
            return {
                "connected": session["running"],
                "lines": new_lines,
                "last_id": last_id,
                "baud": session["baud"]
            }

    def write_line(self, port, text):
        with self.lock:
            session = self.sessions.get(port)
            if not session or not session["running"]:
                return False, "Port is not open"
            try:
                if not text.endswith("\n"):
                    text += "\n"
                session["serial"].write(text.encode("utf-8"))
                return True, "Sent"
            except Exception as e:
                return False, str(e)

    def reset_esp(self, port):
        with self.lock:
            session = self.sessions.get(port)
            if not session or not session["running"]:
                return False, "Port is not open"
            try:
                ser = session["serial"]
                ser.dtr = False
                ser.rts = True
                time.sleep(0.1)
                ser.dtr = True
                ser.rts = False
                time.sleep(0.1)
                ser.dtr = False
                ser.rts = False
                return True, "Reset pulse sent"
            except Exception as e:
                return False, str(e)

    def close_port(self, port):
        with self.lock:
            session = self.sessions.pop(port, None)
            if session:
                session["running"] = False
                try:
                    session["serial"].close()
                except Exception:
                    pass
                return True
            return False

terminal_manager = SerialTerminalManager()

# Global Flash Job State Manager
class FlashJobManager:
    def __init__(self):
        self.lock = threading.Lock()
        self.status = "idle"  # idle, running, finished, aborted
        self.active_processes = {}  # port -> Popen
        self.start_time = 0
        self.end_time = 0
        self.project_name = ""
        self.ports_data = {}  # port -> {status, progress, stage, log, elapsed, error}

    def reset(self, project_name, ports):
        with self.lock:
            self.status = "running"
            self.project_name = project_name
            self.start_time = time.time()
            self.end_time = 0
            self.active_processes = {}
            self.ports_data = {}
            for p in ports:
                self.ports_data[p] = {
                    "status": "pending",  # pending, connecting, erasing, writing, success, failed
                    "progress": 0,
                    "stage": "Waiting to start...",
                    "log": [],
                    "elapsed": 0.0,
                    "error": None
                }

    def update_port(self, port, **kwargs):
        with self.lock:
            if port in self.ports_data:
                for k, v in kwargs.items():
                    if k == "log_append":
                        self.ports_data[port]["log"].append(v)
                        if len(self.ports_data[port]["log"]) > 150:
                            self.ports_data[port]["log"].pop(0)
                    else:
                        self.ports_data[port][k] = v

    def stop_all(self):
        with self.lock:
            self.status = "aborted"
            for p, proc in list(self.active_processes.items()):
                try:
                    proc.terminate()
                except Exception:
                    pass
            for p in self.ports_data:
                if self.ports_data[p]["status"] in ("pending", "connecting", "erasing", "writing"):
                    self.ports_data[p]["status"] = "failed"
                    self.ports_data[p]["stage"] = "Aborted by user"
                    self.ports_data[p]["error"] = "Operation cancelled"

    def get_snapshot(self):
        with self.lock:
            now = time.time()
            elapsed_total = (self.end_time - self.start_time) if self.end_time else (now - self.start_time if self.start_time else 0.0)
            
            succeeded = sum(1 for p, d in self.ports_data.items() if d["status"] == "success")
            failed = sum(1 for p, d in self.ports_data.items() if d["status"] == "failed")
            in_progress = sum(1 for p, d in self.ports_data.items() if d["status"] in ("pending", "connecting", "erasing", "writing"))

            if self.status == "running" and in_progress == 0 and len(self.ports_data) > 0:
                self.status = "finished"
                self.end_time = now

            return {
                "status": self.status,
                "project": self.project_name,
                "total_ports": len(self.ports_data),
                "succeeded": succeeded,
                "failed": failed,
                "in_progress": in_progress,
                "elapsed_time": round(elapsed_total, 1),
                "ports": self.ports_data
            }

job_manager = FlashJobManager()

def get_connected_ports():
    if not list_ports:
        return []
    ports = []
    for p in list_ports.comports():
        haystack = f"{p.description or ''} {p.manufacturer or ''} {p.hwid or ''}".lower()
        is_esp = any(hint in haystack for hint in ESP_PORT_HINTS)
        is_open_in_term = p.device in terminal_manager.sessions
        ports.append({
            "port": p.device,
            "description": p.description or "Serial Port",
            "manufacturer": p.manufacturer or "",
            "is_esp": is_esp,
            "terminal_open": is_open_in_term
        })
    return sorted(ports, key=lambda x: (not x["is_esp"], x["port"]))

def get_available_targets():
    targets = []
    for proj_dir in [FIRMWARE_DIR / "IPS_Mesh_Node", FIRMWARE_DIR / "IPS_Mesh_Root"]:
        if not proj_dir.is_dir():
            continue
        flasher_args_path = proj_dir / "build" / "flasher_args.json"
        has_build = flasher_args_path.exists()
        info = {
            "name": proj_dir.name,
            "path": str(proj_dir),
            "has_build": has_build,
            "chip": "esp32",
            "files": [],
            "total_size": 0,
            "build_time": ""
        }
        if has_build:
            try:
                with open(flasher_args_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    info["chip"] = data.get("extra_esptool_args", {}).get("chip", "esp32")
                    files = data.get("flash_files", {})
                    total_size = 0
                    for offset, rel in files.items():
                        full_p = proj_dir / "build" / rel
                        sz = full_p.stat().st_size if full_p.exists() else 0
                        total_size += sz
                        info["files"].append({"offset": offset, "file": rel, "size": sz})
                    info["total_size"] = total_size
                mtime = flasher_args_path.stat().st_mtime
                info["build_time"] = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(mtime))
            except Exception as e:
                info["build_error"] = str(e)
        targets.append(info)
    return targets

def execute_flash_worker(port, project_dir, baud, erase_only):
    start_t = time.time()
    
    # Crucial: Disconnect any active terminal session on this port before flashing!
    terminal_manager.close_port(port)

    job_manager.update_port(port, status="connecting", stage="Connecting to ESP32...")

    # Load args
    if not erase_only:
        args_file = project_dir / "build" / "flasher_args.json"
        if not args_file.exists():
            job_manager.update_port(port, status="failed", stage="Missing build files", error="flasher_args.json not found")
            return
        with open(args_file, "r", encoding="utf-8") as f:
            flasher_args = json.load(f)

        chip = flasher_args.get("extra_esptool_args", {}).get("chip", "esp32")
        write_flash_args = flasher_args.get("write_flash_args", [])
        flash_files = flasher_args.get("flash_files", {})

        cmd = [
            PYTHON_EXE, "-m", "esptool",
            "--chip", chip,
            "--port", port,
            "--baud", str(baud),
            "--before", "default_reset",
            "--after", "hard_reset",
            "write_flash"
        ] + write_flash_args

        for offset, rel_path in flash_files.items():
            cmd += [offset, str(project_dir / "build" / rel_path)]
    else:
        cmd = [
            PYTHON_EXE, "-m", "esptool",
            "--chip", "esp32",
            "--port", port,
            "--baud", str(baud),
            "erase_flash"
        ]

    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        with job_manager.lock:
            job_manager.active_processes[port] = proc

        pct_regex = re.compile(r"\((\d+)\s*%\)")
        curr_progress = 0
        buf = ""

        while True:
            ch = proc.stdout.read(1)
            if not ch:
                if proc.poll() is not None:
                    break
                time.sleep(0.01)
                continue

            if ch in ("\r", "\n"):
                line = buf.strip()
                buf = ""
                if not line:
                    continue

                job_manager.update_port(port, log_append=line)

                if "Connecting" in line:
                    job_manager.update_port(port, status="connecting", stage="Connecting...")
                elif "Erasing flash" in line:
                    job_manager.update_port(port, status="erasing", stage="Erasing flash chip...", progress=15)
                elif "Writing at" in line:
                    m = pct_regex.search(line)
                    if m:
                        pct = int(m.group(1))
                        curr_progress = pct
                        job_manager.update_port(port, status="writing", stage=f"Writing Flash ({pct}%)", progress=pct)
                    else:
                        job_manager.update_port(port, status="writing", stage="Writing Flash...")
                elif "Hash of data verified" in line:
                    job_manager.update_port(port, stage="Hash verified!", progress=99)
                elif "Hard resetting" in line:
                    job_manager.update_port(port, stage="Resetting board...", progress=100)
            else:
                buf += ch

        ret = proc.wait()
        elapsed = round(time.time() - start_t, 1)

        if ret == 0:
            job_manager.update_port(
                port,
                status="success",
                stage=f"Completed in {elapsed}s",
                progress=100,
                elapsed=elapsed
            )
        else:
            job_manager.update_port(
                port,
                status="failed",
                stage="Flash failed",
                error=f"esptool exited with code {ret}",
                elapsed=elapsed
            )

    except Exception as e:
        elapsed = round(time.time() - start_t, 1)
        job_manager.update_port(
            port,
            status="failed",
            stage="Execution error",
            error=str(e),
            elapsed=elapsed,
            log_append=f"Exception: {e}"
        )
    finally:
        with job_manager.lock:
            if port in job_manager.active_processes:
                del job_manager.active_processes[port]


class FlasherHTTPRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(UI_DIR), **kwargs)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/api/ports":
            ports = get_connected_ports()
            self._send_json({"ports": ports})
        elif path == "/api/targets":
            targets = get_available_targets()
            self._send_json({"targets": targets})
        elif path == "/api/progress":
            snapshot = job_manager.get_snapshot()
            self._send_json(snapshot)
        elif path == "/api/terminal/poll":
            qs = parse_qs(parsed.query)
            port = qs.get("port", [""])[0]
            since = int(qs.get("since", [0])[0])
            res = terminal_manager.poll_lines(port, since_id=since)
            self._send_json(res)
        elif path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
        else:
            super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            data = json.loads(body)
        except Exception:
            data = {}

        if path == "/api/flash":
            project_name = data.get("project", "IPS_Mesh_Node")
            ports = data.get("ports", [])
            baud = data.get("baud", 460800)
            erase_only = bool(data.get("erase", False))

            if not ports:
                self._send_json({"error": "No ports specified"}, status=400)
                return

            if job_manager.status == "running":
                self._send_json({"error": "A flashing job is already running"}, status=409)
                return

            project_dir = FIRMWARE_DIR / project_name
            job_manager.reset(project_name, ports)

            for p in ports:
                t = threading.Thread(
                    target=execute_flash_worker,
                    args=(p, project_dir, baud, erase_only),
                    daemon=True
                )
                t.start()

            self._send_json({"status": "started", "ports": ports})

        elif path == "/api/stop":
            job_manager.stop_all()
            self._send_json({"status": "stopped"})

        elif path == "/api/terminal/open":
            port = data.get("port", "")
            baud = int(data.get("baud", 115200))
            ok, msg = terminal_manager.open_port(port, baud)
            self._send_json({"ok": ok, "message": msg}, status=200 if ok else 400)

        elif path == "/api/terminal/send":
            port = data.get("port", "")
            text = data.get("text", "")
            ok, msg = terminal_manager.write_line(port, text)
            self._send_json({"ok": ok, "message": msg}, status=200 if ok else 400)

        elif path == "/api/terminal/reset":
            port = data.get("port", "")
            ok, msg = terminal_manager.reset_esp(port)
            self._send_json({"ok": ok, "message": msg}, status=200 if ok else 400)

        elif path == "/api/terminal/close":
            port = data.get("port", "")
            terminal_manager.close_port(port)
            self._send_json({"ok": True, "message": "Closed"})

        else:
            self._send_json({"error": "Not found"}, status=404)

    def _send_json(self, data, status=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        if args and isinstance(args[0], str) and ("/api/progress" in args[0] or "/api/ports" in args[0] or "/api/terminal" in args[0]):
            return
        super().log_message(format, *args)


def run_server(port=8585, open_browser=True):
    UI_DIR.mkdir(parents=True, exist_ok=True)
    server_address = ("127.0.0.1", port)
    
    try:
        httpd = HTTPServer(server_address, FlasherHTTPRequestHandler)
    except OSError:
        port += 1
        server_address = ("127.0.0.1", port)
        httpd = HTTPServer(server_address, FlasherHTTPRequestHandler)

    url = f"http://localhost:{port}"
    print(f"\n=======================================================")
    print(f"  ⚡ ESP32 Parallel Multi-Flasher Web UI with Terminal")
    print(f"  🌐 URL: {url}")
    print(f"  🔌 Python: {PYTHON_EXE}")
    print(f"  Press Ctrl+C to stop the server")
    print(f"=======================================================\n")

    if open_browser:
        threading.Timer(1.0, lambda: webbrowser.open(url)).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        job_manager.stop_all()
        httpd.server_close()

if __name__ == "__main__":
    run_server()
