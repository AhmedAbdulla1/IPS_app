#!/usr/bin/env python3
"""
server.py — TRANEX IPS System Monitor Local Server & Database Storage Service
Provides static file serving and writes structured telemetry history into:
  firmware/tools/system-monitor/data/history/
"""

import os
import sys
import json
import time
from datetime import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT = 8088
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data", "history")

os.makedirs(DATA_DIR, exist_ok=True)

class TranexServerHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BASE_DIR, **kwargs)

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/telemetry" or parsed.path == "/api/log":
            content_length = int(self.headers.get("Content-Length", 0))
            post_data = self.rfile.read(content_length)
            
            try:
                payload = json.loads(post_data.decode("utf-8"))
                date_str = datetime.now().strftime("%Y-%m-%d")
                log_file = os.path.join(DATA_DIR, f"telemetry_{date_str}.jsonl")
                
                if isinstance(payload, list):
                    records = payload
                elif isinstance(payload, dict) and "records" in payload and isinstance(payload["records"], list):
                    records = payload["records"]
                else:
                    records = [payload]
                
                with open(log_file, "a", encoding="utf-8") as f:
                    for item in records:
                        if not item.get("server_ts"):
                            item["server_ts"] = int(time.time() * 1000)
                        f.write(json.dumps(item, ensure_ascii=False) + "\n")
                
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "ok", "saved": len(records)}).encode("utf-8"))
                return
            except Exception as e:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode("utf-8"))
                return

        super().do_POST()

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/history":
            query = parse_qs(parsed.query)
            node_filter = query.get("node", [None])[0]
            if node_filter == "ALL":
                node_filter = None
            limit = int(query.get("limit", [100])[0])
            date_str = query.get("date", [datetime.now().strftime("%Y-%m-%d")])[0]
            
            log_file = os.path.join(DATA_DIR, f"telemetry_{date_str}.jsonl")
            results = []
            
            if os.path.exists(log_file):
                with open(log_file, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                    for line in reversed(lines):
                        if not line.strip():
                            continue
                        try:
                            record = json.loads(line)
                            # Handle nested wrapper if any legacy entry was written
                            if "records" in record and isinstance(record["records"], list):
                                for r in reversed(record["records"]):
                                    n_id = r.get("nodeUuid") or r.get("nodeId") or r.get("node_id") or r.get("uuid")
                                    if node_filter and n_id != node_filter and str(n_id) != str(node_filter):
                                        continue
                                    results.append(r)
                                    if len(results) >= limit:
                                        break
                                if len(results) >= limit:
                                    break
                                continue

                            n_id = record.get("nodeUuid") or record.get("nodeId") or record.get("node_id") or record.get("uuid")
                            if node_filter and n_id != node_filter and str(n_id) != str(node_filter):
                                continue
                            results.append(record)
                            if len(results) >= limit:
                                break
                        except Exception:
                            continue

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"count": len(results), "records": results}, ensure_ascii=False).encode("utf-8"))
            return

        super().do_GET()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

def run():
    server_address = ("", PORT)
    httpd = HTTPServer(server_address, TranexServerHandler)
    print(f"[TRANEX SERVER] Running on http://localhost:{PORT}")
    print(f"[TRANEX SERVER] Local telemetry database active at: {DATA_DIR}")
    httpd.serve_forever()

if __name__ == "__main__":
    run()
