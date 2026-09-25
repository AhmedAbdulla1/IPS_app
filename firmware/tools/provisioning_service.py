#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
provisioning_service.py - ESP32 Node Provisioning & History Service
Handles:
- Direct Serial command execution: SET_ID:<hex>, GET_ID
- Cryptographic UID generation (16 bytes = 32 hex chars)
- Cloud registration with Supabase (nodes table)
- Persistent local history (provisioning_history.json) with reprint tracking
"""

import json
import os
import re
import secrets
import sys
import threading
import time
from pathlib import Path

try:
    import serial
except ImportError:
    serial = None

try:
    import requests
except ImportError:
    requests = None

# Base paths
SCRIPT_DIR = Path(__file__).resolve().parent
HISTORY_FILE = SCRIPT_DIR / "provisioning_history.json"


def generate_node_uuid_hex():
    """Generates 16 random bytes as a 32-character hexadecimal string."""
    return secrets.token_hex(16)


def format_as_uuid(hex_str):
    """Formats 32 hex chars into standard UUID format (8-4-4-4-12)."""
    clean = re.sub(r"[^0-9a-fA-F]", "", hex_str).lower()
    if len(clean) != 32:
        clean = clean.zfill(32)[:32]
    return f"{clean[0:8]}-{clean[8:12]}-{clean[12:16]}-{clean[16:20]}-{clean[20:32]}"


def clean_hex_id(id_str):
    """Strips hyphens and non-hex characters from ID string."""
    return re.sub(r"[^0-9a-fA-F]", "", str(id_str or "")).lower()


def send_set_id(port, uid_hex, baud=115200, timeout=3.5):
    """
    Sends SET_ID:<hex> command to the ESP32 via Serial port and waits for confirmation.
    Returns: (success: bool, message: str, raw_log: str)
    """
    if not serial:
        return False, "مكتبة pyserial غير مثبتة في النظام", ""

    clean_uid = clean_hex_id(uid_hex)
    if not clean_uid:
        clean_uid = generate_node_uuid_hex()

    try:
        ser = serial.Serial()
        ser.port = port
        ser.baudrate = baud
        ser.timeout = 0.1
        ser.dtr = False
        ser.rts = False
        ser.open()
    except Exception as e:
        return False, f"فشل فتح منفذ السيريال {port}: {e}", ""

    raw_chunks = []
    try:
        # Clear buffers
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.05)

        # Send command
        cmd_str = f"SET_ID:{clean_uid}\n"
        ser.write(cmd_str.encode("utf-8"))
        ser.flush()

        start_time = time.time()
        success = False
        while (time.time() - start_time) < timeout:
            chunk = ser.read(ser.in_waiting or 1)
            if chunk:
                text = chunk.decode("utf-8", errors="replace")
                raw_chunks.append(text)
                combined = "".join(raw_chunks)
                if "saved to NVS" in combined or "Rebooting" in combined:
                    success = True
                    break
            else:
                time.sleep(0.02)

        raw_output = "".join(raw_chunks).strip()
        if success:
            return True, f"تم حفظ الـ UID ({clean_uid}) بنجاح في ذاكرة NVS على البوردة!", raw_output
        else:
            if "ERROR" in raw_output:
                return False, f"ردت البوردة بخطأ: {raw_output}", raw_output
            elif raw_output:
                return False, f"لم يتم استلام تأكيد الحفظ. الرد المستلم: {raw_output}", raw_output
            else:
                return False, "لم يتم استلام أي رد من البوردة خلال المهلة المحددة", ""
    except Exception as e:
        return False, f"خطأ أثناء الإرسال للبوردة: {e}", "".join(raw_chunks)
    finally:
        try:
            ser.close()
        except Exception:
            pass


def send_get_id(port, baud=115200, timeout=2.0):
    """
    Sends GET_ID command to query the currently stored UID on the ESP32.
    Returns: (success: bool, current_uid: str, raw_output: str)
    """
    if not serial:
        return False, "", "pyserial not available"

    try:
        ser = serial.Serial()
        ser.port = port
        ser.baudrate = baud
        ser.timeout = 0.1
        ser.dtr = False
        ser.rts = False
        ser.open()
    except Exception as e:
        return False, "", f"فشل فتح منفذ {port}: {e}"

    raw_chunks = []
    try:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        ser.write(b"GET_ID\n")
        ser.flush()

        start_time = time.time()
        while (time.time() - start_time) < timeout:
            chunk = ser.read(ser.in_waiting or 1)
            if chunk:
                text = chunk.decode("utf-8", errors="replace")
                raw_chunks.append(text)
                combined = "".join(raw_chunks)
                if "Current Node ID:" in combined or "node_id" in combined:
                    break
            else:
                time.sleep(0.02)

        raw_output = "".join(raw_chunks).strip()
        # Parse hex ID
        match = re.search(r"Current Node ID:\s*([0-9a-fA-F]+)", raw_output)
        if match:
            uid_found = match.group(1).strip()
            return True, uid_found, raw_output
        return False, "", raw_output
    except Exception as e:
        return False, "", str(e)
    finally:
        try:
            ser.close()
        except Exception:
            pass


def insert_node_to_supabase(payload, supabase_url, supabase_key):
    """
    Inserts or upserts node into Supabase 'nodes' table via REST API.
    """
    if not requests:
        return False, "مكتبة requests غير متوفرة"

    url = f"{supabase_url.rstrip('/')}/rest/v1/nodes"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=representation"
    }

    try:
        body = [payload] if isinstance(payload, dict) else payload
        res = requests.post(url, headers=headers, json=body, timeout=8)
        if res.status_code in (200, 201):
            return True, res.json()
        else:
            return False, f"HTTP {res.status_code}: {res.text}"
    except Exception as e:
        return False, f"استثناء الاتصال بـ Supabase: {e}"


class ProvisioningHistoryStore:
    """
    Thread-safe permanent storage for provisioned nodes in provisioning_history.json.
    """
    def __init__(self, filepath=HISTORY_FILE):
        self.filepath = filepath
        self.lock = threading.Lock()
        self.data = self._load()

    def _load(self):
        if self.filepath.exists():
            try:
                with open(self.filepath, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception as e:
                print(f"Error loading provisioning history: {e}")
        return {
            "stats": {
                "total_provisioned": 0,
                "total_labels_printed": 0,
                "last_updated": time.strftime("%Y-%m-%d %H:%M:%S")
            },
            "records": []
        }

    def _save(self):
        try:
            with open(self.filepath, "w", encoding="utf-8") as f:
                json.dump(self.data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"Error saving provisioning history: {e}")

    def add_record(self, record):
        with self.lock:
            records = self.data.setdefault("records", [])
            stats = self.data.setdefault("stats", {})

            # Assign sequential ID
            record_id = (records[0]["id"] + 1) if records else 1
            entry = {
                "id": record_id,
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                "node_id": record.get("node_id"),
                "level_id": record.get("level_id", "GF"),
                "x": record.get("x", 0),
                "y": record.get("y", 0),
                "type": record.get("type", "poi"),
                "name_ar": record.get("name_ar", ""),
                "name_en": record.get("name_en", ""),
                "esp32_uuid": record.get("esp32_uuid", ""),
                "port": record.get("port", ""),
                "serial_ok": bool(record.get("serial_ok", False)),
                "db_ok": bool(record.get("db_ok", False)),
                "print_ok": bool(record.get("print_ok", False)),
                "printed_count": 1 if record.get("print_ok") else 0,
                "notes": record.get("notes", "")
            }

            # Insert at beginning
            records.insert(0, entry)
            if len(records) > 1000:
                self.data["records"] = records[:1000]

            stats["total_provisioned"] = len(records)
            stats["total_labels_printed"] = sum(r.get("printed_count", 0) for r in records)
            stats["last_updated"] = time.strftime("%Y-%m-%d %H:%M:%S")

            self._save()
            return entry

    def record_print_event(self, node_id):
        """Increments printed count for a specific node."""
        with self.lock:
            records = self.data.setdefault("records", [])
            for r in records:
                if str(r.get("node_id")) == str(node_id):
                    r["printed_count"] = r.get("printed_count", 0) + 1
                    r["print_ok"] = True
                    break
            self.data["stats"]["total_labels_printed"] = sum(r.get("printed_count", 0) for r in records)
            self._save()

    def get_data(self):
        with self.lock:
            return {
                "stats": self.data.get("stats", {}),
                "records": self.data.get("records", [])
            }

    def delete_record(self, record_id):
        with self.lock:
            records = self.data.setdefault("records", [])
            self.data["records"] = [r for r in records if r["id"] != int(record_id)]
            self.data["stats"]["total_provisioned"] = len(self.data["records"])
            self._save()
            return True

    def clear_all(self):
        with self.lock:
            self.data = {
                "stats": {
                    "total_provisioned": 0,
                    "total_labels_printed": 0,
                    "last_updated": time.strftime("%Y-%m-%d %H:%M:%S")
                },
                "records": []
            }
            self._save()
            return True


history_store = ProvisioningHistoryStore()


if __name__ == "__main__":
    print(f"Generated UID Hex: {generate_node_uuid_hex()}")
    formatted = format_as_uuid(generate_node_uuid_hex())
    print(f"Formatted UUID: {formatted}")
    print(f"History Stats: {history_store.get_data()['stats']}")
