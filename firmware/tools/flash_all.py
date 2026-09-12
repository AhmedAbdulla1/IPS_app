#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
flash_all.py - يرفع build واحدة (بيلد ESP-IDF جاهزة) على كذا بورد ESP32
متوصلين على أكتر من COM port مع بعض في نفس الوقت (parallel).

استخدام أساسي (بعد ما تعمل idf.py build مرة واحدة):
    python flash_all.py --project E:\\IPS_app\\firmware\\IPS_Mesh_Node

بيكتشف كل البورتات المتوصلة تلقائيًا (بيدور على شرائح USB-UART
الشائعة زي CP210x / CH340 / FTDI)، ويعرضهم عليك، ويستناك تأكيد قبل
ما يبدأ. لو عايز تحدد بورتات بعينها:
    python flash_all.py --project E:\\IPS_app\\firmware\\IPS_Mesh_Node --ports COM8,COM9,COM12

خيارات تانية:
    --baud 460800        سرعة الفلاش (افتراضي 460800، نزّلها لو بتفشل)
    --erase              يعمل erase_flash بس (بدل رفع الكود) - مفيد
                          قبل رفع أول نسخة على بورد جديد أو لو NVS
                          قديم بيسبب مشاكل provisioning.
    --yes                يتخطى سؤال التأكيد (مفيد لو بتستخدمه من سكريبت تاني)

ملحوظة مهمة: لازم تشغّل السكريبت ده بنفس بايثون بتاع ESP-IDF (اللي فيه
esptool مثبت جواه) - يعني من نفس الـPowerShell terminal اللي بتعمل فيه
idf.py build عادي (بعد ما تكون شغّلت export.bat / activated الـvenv).
"""

import argparse
import json
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

try:
    import serial.tools.list_ports as list_ports
except ImportError:
    print("محتاج مكتبة pyserial. شغل: pip install pyserial")
    sys.exit(1)

# كلمات مفتاحية بتدل غالبًا على إن البورت متوصل بيه شريحة USB-UART
# شائعة الاستخدام في بوردات ESP32 (CP2102, CH340/CH9102, FTDI...).
ESP_PORT_HINTS = (
    "cp210", "ch340", "ch9102", "ftdi", "usb-serial", "usb serial",
    "silicon labs", "usb2.0-serial", "uart",
)


def find_esp_ports():
    """بيرجع قائمة بكل الـCOM ports اللي شكلها ESP32 (من الوصف/الشركة المصنّعة)."""
    ports = []
    for p in list_ports.comports():
        haystack = f"{p.description or ''} {p.manufacturer or ''}".lower()
        if any(hint in haystack for hint in ESP_PORT_HINTS):
            ports.append(p.device)
    return sorted(ports)


def load_flasher_args(project_dir: Path):
    args_file = project_dir / "build" / "flasher_args.json"
    if not args_file.exists():
        print(f"❌ مفيش build جاهزة. شغل الأول:\n   cd {project_dir}\n   idf.py build")
        sys.exit(1)
    with open(args_file, "r", encoding="utf-8") as f:
        return json.load(f)


def build_flash_cmd(flasher_args, project_dir: Path, port: str, baud: str):
    chip = flasher_args.get("extra_esptool_args", {}).get("chip", "esp32")
    write_flash_args = flasher_args["write_flash_args"]
    flash_files = flasher_args["flash_files"]

    cmd = [
        sys.executable, "-m", "esptool",
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
        sys.executable, "-m", "esptool",
        "--chip", chip,
        "--port", port,
        "--baud", str(baud),
        "erase_flash",
    ]


def flash_one(port, cmd, results, lock, log_dir: Path):
    start = time.time()
    log_path = log_dir / f"{port.replace(':', '_')}.log"
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        ok = proc.returncode == 0
        output = (proc.stdout or "") + "\n" + (proc.stderr or "")
    except Exception as e:  # noqa: BLE001 - عايزين نمسك أي فشل ونعرضه، مش نوقف باقي الترابيط
        ok = False
        output = f"استثناء وقت تشغيل esptool: {e}"

    elapsed = time.time() - start
    log_path.write_text(output, encoding="utf-8", errors="replace")

    with lock:
        status = "✅ نجح" if ok else "❌ فشل"
        print(f"[{port}] {status}  ({elapsed:.1f}s)  - لوج كامل في: {log_path}")
        if not ok:
            tail = output.strip().splitlines()[-15:]
            print(f"    آخر سطور من اللوج بتاع {port}:")
            for line in tail:
                print(f"      {line}")

    results[port] = ok


def main():
    parser = argparse.ArgumentParser(description="فلاش build واحدة على كذا ESP32 مع بعض بالتوازي")
    parser.add_argument("--project", required=True, help="مسار مشروع ESP-IDF (لازم فيه build/ جاهزة)")
    parser.add_argument("--ports", default=None, help="COM ports مفصولة بفاصلة، مثلاً COM8,COM9,COM12")
    parser.add_argument("--baud", default="460800", help="سرعة الفلاش (افتراضي 460800)")
    parser.add_argument("--erase", action="store_true", help="erase_flash بس، من غير رفع كود")
    parser.add_argument("--yes", action="store_true", help="متخطاش سؤال التأكيد")
    args = parser.parse_args()

    project_dir = Path(args.project)

    if args.ports:
        ports = [p.strip() for p in args.ports.split(",") if p.strip()]
    else:
        ports = find_esp_ports()

    if not ports:
        print("⚠️  مفيش بورتات ESP32 متكشفة تلقائيًا.")
        print("   جرب تحدد البورتات يدويًا: --ports COM8,COM9,COM12")
        print("   أو تأكد إن الدرايفر (CP210x/CH340) متثبت.")
        sys.exit(1)

    action = "مسح (erase)" if args.erase else "رفع الكود من"
    print(f"لاقيت {len(ports)} بورت: {', '.join(ports)}")
    print(f"العملية: {action} {project_dir if not args.erase else ''}")

    if not args.yes:
        confirm = input("متأكد عايز تكمل على البورتات دي كلها؟ (y/n): ").strip().lower()
        if confirm != "y":
            print("اتلغى.")
            sys.exit(0)

    flasher_args = None if args.erase else load_flasher_args(project_dir)

    log_dir = project_dir / "flash_logs" / datetime.now().strftime("%Y%m%d_%H%M%S")
    log_dir.mkdir(parents=True, exist_ok=True)
    print(f"لوجات كل بورت هتتحفظ في: {log_dir}\n")

    threads = []
    results = {}
    lock = threading.Lock()

    for port in ports:
        if args.erase:
            cmd = build_erase_cmd(flasher_args or {"extra_esptool_args": {"chip": "esp32"}}, port, args.baud)
        else:
            cmd = build_flash_cmd(flasher_args, project_dir, port, args.baud)
        t = threading.Thread(target=flash_one, args=(port, cmd, results, lock, log_dir))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    print("\n=== الملخص ===")
    for port in ports:
        ok = results.get(port, False)
        print(f"  {port}: {'✅ نجح' if ok else '❌ فشل'}")

    fail_count = sum(1 for ok in results.values() if not ok)
    if fail_count:
        print(f"\n⚠️  {fail_count} من {len(ports)} بورت فشل. راجع اللوجات في {log_dir}")
        sys.exit(1)

    print(f"\n🎉 كل الـ{len(ports)} بورت اتفلشوا بنجاح!")


if __name__ == "__main__":
    main()
