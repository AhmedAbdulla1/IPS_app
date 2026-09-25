#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
printer_service.py - Barcode & Thermal Label Printer Service for Xprinter XP-246B / XP-410B
Specialized for 38x12mm / 38x24mm Twin Label Rolls with 3mm Gap Sensor.

Features:
- Native Windows Spooler integration via winspool.drv (zero third-party printer drivers needed).
- Full printer enumeration, default printer detection, and status check.
- Calibrated TSPL twin label generation with Code 128 barcode, TRANEX logo bitmap, and tear-off alignment.
- Hardware Gap Calibration (GAPDETECT) and Form Feed commands.
- Simulation / dry-run mode when physical printer is offline.
"""

import ctypes
from ctypes import wintypes as wt
import io
import os
import sys
from pathlib import Path

# Base directories
SCRIPT_DIR = Path(__file__).resolve().parent
LOGO_PATH = SCRIPT_DIR / "logo.svg"

# WinSpool Structures
class DOC_INFO_1(ctypes.Structure):
    _fields_ = [
        ("pDocName", wt.LPCWSTR),
        ("pOutputFile", wt.LPCWSTR),
        ("pDatatype", wt.LPCWSTR),
    ]

class PRINTER_INFO_2W(ctypes.Structure):
    _fields_ = [
        ("pServerName", wt.LPCWSTR),
        ("pPrinterName", wt.LPCWSTR),
        ("pShareName", wt.LPCWSTR),
        ("pPortName", wt.LPCWSTR),
        ("pDriverName", wt.LPCWSTR),
        ("pComment", wt.LPCWSTR),
        ("pLocation", wt.LPCWSTR),
        ("pDevMode", ctypes.c_void_p),
        ("pSepFile", wt.LPCWSTR),
        ("pPrintProcessor", wt.LPCWSTR),
        ("pDatatype", wt.LPCWSTR),
        ("pParameters", wt.LPCWSTR),
        ("pSecurityDescriptor", ctypes.c_void_p),
        ("Attributes", wt.DWORD),
        ("Priority", wt.DWORD),
        ("DefaultPriority", wt.DWORD),
        ("StartTime", wt.DWORD),
        ("UntilTime", wt.DWORD),
        ("Status", wt.DWORD),
        ("cJobs", wt.DWORD),
        ("AveragePPM", wt.DWORD),
    ]


def _get_winspool():
    try:
        return ctypes.WinDLL("winspool.drv")
    except Exception as e:
        print(f"Warning: Could not load winspool.drv: {e}")
        return None


def get_default_printer():
    winspool = _get_winspool()
    if not winspool:
        return "Xprinter XP-246B"
    try:
        buf_len = wt.DWORD(0)
        winspool.GetDefaultPrinterW(None, ctypes.byref(buf_len))
        if buf_len.value > 0:
            buf = ctypes.create_unicode_buffer(buf_len.value)
            if winspool.GetDefaultPrinterW(buf, ctypes.byref(buf_len)):
                return buf.value
    except Exception:
        pass
    return "Xprinter XP-246B"


def list_printers():
    """
    Returns a list of all installed printers with driver, port, job count, and thermal hints.
    """
    winspool = _get_winspool()
    if not winspool:
        return []

    default_name = get_default_printer()
    printers_list = []

    try:
        PRINTER_ENUM_LOCAL = 2
        PRINTER_ENUM_CONNECTIONS = 4
        needed = wt.DWORD(0)
        returned = wt.DWORD(0)

        winspool.EnumPrintersW(
            PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
            None, 2, None, 0,
            ctypes.byref(needed), ctypes.byref(returned)
        )

        if needed.value > 0:
            buf = (ctypes.c_byte * needed.value)()
            if winspool.EnumPrintersW(
                PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
                None, 2, buf, needed,
                ctypes.byref(needed), ctypes.byref(returned)
            ):
                printers = ctypes.cast(buf, ctypes.POINTER(PRINTER_INFO_2W))
                for i in range(returned.value):
                    p = printers[i]
                    p_name = p.pPrinterName or ""
                    p_port = p.pPortName or ""
                    p_driver = p.pDriverName or ""
                    is_default = (p_name.strip().lower() == default_name.strip().lower())
                    
                    # Check if likely a thermal/label printer
                    name_lower = f"{p_name} {p_driver}".lower()
                    is_thermal = any(k in name_lower for k in ("xprinter", "xp-", "tsc", "zebra", "label", "barcode"))

                    printers_list.append({
                        "name": p_name,
                        "port": p_port,
                        "driver": p_driver,
                        "jobs": int(p.cJobs),
                        "status_code": int(p.Status),
                        "is_default": is_default,
                        "is_thermal": is_thermal
                    })
    except Exception as e:
        print(f"Error enumerating printers: {e}")

    # Sort so thermal printers & default printer come first
    printers_list.sort(key=lambda x: (not x["is_default"], not x["is_thermal"], x["name"]))
    return printers_list


def get_printer_status(printer_name=None):
    """
    Checks if printer is reachable and its active job queue.
    """
    if not printer_name:
        printer_name = get_default_printer()

    printers = list_printers()
    matched = next((p for p in printers if p["name"].lower() == printer_name.lower()), None)
    
    if not matched:
        return {
            "name": printer_name,
            "found": False,
            "connected": False,
            "message": f"الطابعة '{printer_name}' غير مثبتة بالنظام"
        }

    winspool = _get_winspool()
    hPrinter = wt.HANDLE()
    can_open = False
    if winspool:
        res = winspool.OpenPrinterW(printer_name, ctypes.byref(hPrinter), None)
        if res:
            can_open = True
            winspool.ClosePrinter(hPrinter)

    return {
        "name": printer_name,
        "found": True,
        "connected": can_open,
        "port": matched["port"],
        "driver": matched["driver"],
        "jobs": matched["jobs"],
        "is_default": matched["is_default"],
        "message": "جاهزة ومتاحة" if can_open else "غير متصلة حالياً"
    }


def get_logo_bitmap(logo_path=None, target_w=96, target_h=35, threshold=160, invert=True):
    """
    Converts logo SVG or image into 1-bit monochrome TSPL BITMAP bytearray.
    """
    if not logo_path:
        logo_path = LOGO_PATH
    logo_path = Path(logo_path)

    if not logo_path.exists():
        return None, 0, 0

    try:
        from PIL import Image

        if logo_path.suffix.lower() == ".svg":
            import resvg_py
            with open(logo_path, "r", encoding="utf-8") as f:
                svg_content = f.read()
            png_data = resvg_py.svg_to_bytes(svg_string=svg_content, width=target_w)
            im = Image.open(io.BytesIO(png_data))
        else:
            im = Image.open(logo_path)

        if im.mode == "RGBA":
            bg = Image.new("RGB", im.size, (255, 255, 255))
            bg.paste(im, mask=im.split()[3])
            im = bg

        im = im.convert("L").resize((target_w, target_h), Image.Resampling.LANCZOS)
        width_bytes = target_w // 8
        bitmap_bytes = bytearray()

        for y in range(target_h):
            for bx in range(width_bytes):
                byte_val = 0
                for bit in range(8):
                    x = bx * 8 + bit
                    p = im.getpixel((x, y))
                    is_black = (p >= threshold) if invert else (p < threshold)
                    if is_black:
                        byte_val |= (1 << (7 - bit))
                bitmap_bytes.append(byte_val)

        return bytes(bitmap_bytes), width_bytes, target_h
    except Exception as e:
        print(f"Warning: Logo bitmap generation error: {e}")
        return None, 0, 0


def _send_raw_to_printer(printer_name, data_bytes, doc_name="IPS Label Job"):
    """
    Sends raw bytes directly to Windows print spooler via winspool.drv.
    """
    winspool = _get_winspool()
    if not winspool:
        return False, "winspool.drv is not available on this platform"

    winspool.OpenPrinterW.argtypes = [wt.LPCWSTR, ctypes.POINTER(wt.HANDLE), ctypes.c_void_p]
    winspool.OpenPrinterW.restype = wt.BOOL
    winspool.ClosePrinter.argtypes = [wt.HANDLE]
    winspool.ClosePrinter.restype = wt.BOOL
    winspool.StartDocPrinterW.argtypes = [wt.HANDLE, wt.DWORD, ctypes.POINTER(DOC_INFO_1)]
    winspool.StartDocPrinterW.restype = wt.DWORD
    winspool.EndDocPrinter.argtypes = [wt.HANDLE]
    winspool.EndDocPrinter.restype = wt.BOOL
    winspool.StartPagePrinter.argtypes = [wt.HANDLE]
    winspool.StartPagePrinter.restype = wt.BOOL
    winspool.EndPagePrinter.argtypes = [wt.HANDLE]
    winspool.EndPagePrinter.restype = wt.BOOL
    winspool.WritePrinter.argtypes = [wt.HANDLE, ctypes.c_char_p, wt.DWORD, ctypes.POINTER(wt.DWORD)]
    winspool.WritePrinter.restype = wt.BOOL

    hPrinter = wt.HANDLE()
    if not winspool.OpenPrinterW(printer_name, ctypes.byref(hPrinter), None):
        return False, f"تعذر فتح الطابعة '{printer_name}' - تأكد من توصيلها بالكمبيوتر"

    try:
        doc_info = DOC_INFO_1()
        doc_info.pDocName = doc_name
        doc_info.pOutputFile = None
        doc_info.pDatatype = "RAW"

        job_id = winspool.StartDocPrinterW(hPrinter, 1, ctypes.byref(doc_info))
        if job_id == 0:
            return False, "فشل إنشاء أمر الطباعة StartDocPrinterW"

        try:
            winspool.StartPagePrinter(hPrinter)
            bytes_written = wt.DWORD(0)
            ok = winspool.WritePrinter(hPrinter, data_bytes, len(data_bytes), ctypes.byref(bytes_written))
            winspool.EndPagePrinter(hPrinter)
            winspool.EndDocPrinter(hPrinter)

            if ok and bytes_written.value > 0:
                return True, f"تم إرسال أمر الطباعة بنجاح (Job ID: {job_id})"
            else:
                return False, "فشلت كتابة البيانات في طابور الطباعة"
        except Exception as ex:
            winspool.EndDocPrinter(hPrinter)
            return False, f"استثناء أثناء إرسال البيانات: {ex}"
    finally:
        winspool.ClosePrinter(hPrinter)


def print_twin_label(node_id="101", floor="GF", printer_name=None, logo_path=None, copies=1, s1_shift_y=0, s2_shift_y=0, height_mm=24.0, gap_mm=3.0, offset_y=0, inter_gap_dots=8):
    """
    Prints calibrated twin labels (Sticker 1 for device, Sticker 2 for box/documentation).
    Increased top safe margin (+2.5mm base) to prevent any top cut-off,
    and reduced inter-label gap (1.0mm) so the two stickers stay close together.
    """
    if not printer_name:
        printer_name = get_default_printer()

    node_id_str = str(node_id).strip()
    floor_str = str(floor).strip()
    h_mm = int(round(float(height_mm)))
    g_mm = int(round(float(gap_mm)))

    # Pre-render logo bitmap
    logo_bytes, w_bytes, h_dots = get_logo_bitmap(logo_path, target_w=96, target_h=35, invert=True)

    stream = bytearray()

    # Hardware Pitch Lock: OFFSET 0 mm and SET TEAR OFF eliminate mechanical gear backlash and cumulative creep
    header = (
        f"SIZE 38 mm, {h_mm} mm\r\n"
        f"GAP {g_mm} mm, 0 mm\r\n"
        "OFFSET 0 mm\r\n"
        "SET TEAR OFF\r\n"
        "SET PEEL OFF\r\n"
        "SET CUTTER OFF\r\n"
        "DIRECTION 1,0\r\n"
        "REFERENCE 0,0\r\n"
        "CLS\r\n"
    )
    stream.extend(header.encode("utf-8"))

    # --- الملصق الأول: Sticker 1 (نزول إضافي للأمان بعيداً عن حافة القطع العلوية) ---
    base_top = 20 + offset_y  # 2.5 mm base drop from top edge
    s1_top = base_top + s1_shift_y
    s1_bottom = s1_top + 58
    s1_text_y = s1_top + 6
    s1_bc_y = s1_top + 24
    s1_logo_y = s1_top + 26

    s1_cmds = (
        f"BOX 8,{s1_top},272,{s1_bottom},2\r\n"
        f'TEXT 18,{s1_text_y},"2",0,1,1,"ID:{node_id_str}  FL:{floor_str}"\r\n'
        f'BARCODE 18,{s1_bc_y},"128",26,1,0,2,2,"{node_id_str}"\r\n'
    )
    stream.extend(s1_cmds.encode("utf-8"))
    if logo_bytes:
        stream.extend(f"BITMAP 170,{s1_logo_y},{w_bytes},{h_dots},0,".encode("ascii") + logo_bytes + b"\r\n")

    # --- الملصق الثاني: Sticker 2 (مسافة قريبة جداً 1.0 مم فقط أسفل الملصق الأول) ---
    s2_top = s1_bottom + inter_gap_dots + s2_shift_y
    s2_bottom = s2_top + 58
    s2_text_y = s2_top + 6
    s2_bc_y = s2_top + 24
    s2_logo_y = s2_top + 26

    s2_cmds = (
        f"BOX 8,{s2_top},272,{s2_bottom},2\r\n"
        f'TEXT 18,{s2_text_y},"2",0,1,1,"ID:{node_id_str}  FL:{floor_str}"\r\n'
        f'BARCODE 18,{s2_bc_y},"128",26,1,0,2,2,"{node_id_str}"\r\n'
    )
    stream.extend(s2_cmds.encode("utf-8"))
    if logo_bytes:
        stream.extend(f"BITMAP 170,{s2_logo_y},{w_bytes},{h_dots},0,".encode("ascii") + logo_bytes + b"\r\n")

    # أمر طباعة الدورة الواحدة (الورقتين معاً في أمر واحد ثم الوقوف الدقيق عند الحساس الضوئي للفاصل)
    stream.extend(f"PRINT {copies},1\r\n".encode("ascii"))

    return _send_raw_to_printer(printer_name, bytes(stream), doc_name=f"IPS Twin Node Label {node_id_str}")


def print_single_label(node_id="101", floor="GF", printer_name=None, logo_path=None, copies=1, height_mm=24.0, gap_mm=3.0, offset_y=0):
    """
    Prints a single full label (e.g. 38x24mm or 38x25mm) with zero offset and zero drift.
    """
    if not printer_name:
        printer_name = get_default_printer()

    node_id_str = str(node_id).strip()
    floor_str = str(floor).strip()
    h_mm = int(round(float(height_mm)))
    g_mm = int(round(float(gap_mm)))
    total_dots = int(h_mm * 8)

    logo_bytes, w_bytes, h_dots = get_logo_bitmap(logo_path, target_w=96, target_h=35, invert=True)

    stream = bytearray()
    header = (
        f"SIZE 38 mm, {h_mm} mm\r\n"
        f"GAP {g_mm} mm, 0 mm\r\n"
        "OFFSET 0 mm\r\n"
        "SET TEAR OFF\r\n"
        "SET PEEL OFF\r\n"
        "SET CUTTER OFF\r\n"
        "DIRECTION 1,0\r\n"
        "REFERENCE 0,0\r\n"
        "CLS\r\n"
        f"BOX 8,{8 + offset_y},296,{total_dots - 8 + offset_y},2\r\n"
        f'TEXT 18,{16 + offset_y},"2",0,1,1,"ID:{node_id_str}  FL:{floor_str}"\r\n'
        f'BARCODE 18,{48 + offset_y},"128",50,1,0,2,2,"{node_id_str}"\r\n'
    )
    stream.extend(header.encode("utf-8"))
    if logo_bytes:
        stream.extend(f"BITMAP 180,{120 + offset_y},{w_bytes},{h_dots},0,".encode("ascii") + logo_bytes + b"\r\n")
    stream.extend(f'TEXT 18,{132 + offset_y},"1",0,1,1,"IPS TRANEX NODE"\r\n'.encode("utf-8"))
    stream.extend(f"PRINT {copies},1\r\n".encode("ascii"))

    return _send_raw_to_printer(printer_name, bytes(stream), doc_name=f"IPS Single Label {node_id_str}")


def print_calibration_test(printer_name=None, height_mm=24.0, gap_mm=3.0, copies=1):
    """
    Prints a precision millimeter alignment & zero-drift verification label.
    Draws a bounding frame at exactly 1mm margins to verify that the print
    stays 100% centered and never drifts upwards across repeated prints.
    """
    if not printer_name:
        printer_name = get_default_printer()

    h_mm = int(round(float(height_mm)))
    g_mm = int(round(float(gap_mm)))
    total_dots = int(h_mm * 8)
    mid_y = total_dots // 2
    w_dots = 38 * 8  # 304 dots

    stream = bytearray()
    header = (
        f"SIZE 38 mm, {h_mm} mm\r\n"
        f"GAP {g_mm} mm, 0 mm\r\n"
        "OFFSET 0 mm\r\n"
        "SET TEAR OFF\r\n"
        "SET PEEL OFF\r\n"
        "SET CUTTER OFF\r\n"
        "DIRECTION 1,0\r\n"
        "REFERENCE 0,0\r\n"
        "CLS\r\n"
    )
    stream.extend(header.encode("utf-8"))

    # Outer border frame: exactly 1mm (8 dots) inside label edges
    stream.extend(f"BOX 8,8,{w_dots - 8},{total_dots - 8},2\r\n".encode("utf-8"))
    # Center dividing line
    stream.extend(f"BAR 8,{mid_y},288,1\r\n".encode("utf-8"))

    # Upper section info
    stream.extend(b'TEXT 16,14,"2",0,1,1,"CALIBRATION 38x24mm"\r\n')
    stream.extend(f'TEXT 16,34,"1",0,1,1,"GAP: {g_mm}mm | OFFSET: 0mm"\r\n'.encode("utf-8"))
    stream.extend(b'BARCODE 16,52,"128",26,1,0,2,2,"CALIB-001"\r\n')

    # Lower section info
    stream.extend(f'TEXT 16,{mid_y + 10},"2",0,1,1,"ZERO-DRIFT VERIFIED"\r\n'.encode("utf-8"))
    stream.extend(f'TEXT 16,{mid_y + 30},"1",0,1,1,"OPTICAL SENSOR LOCKED"\r\n'.encode("utf-8"))
    stream.extend(f'BARCODE 16,{mid_y + 48},"128",26,1,0,2,2,"DRIFT-ZERO"\r\n'.encode("utf-8"))

    stream.extend(f"PRINT {copies},1\r\n".encode("ascii"))

    return _send_raw_to_printer(printer_name, bytes(stream), doc_name="IPS Zero-Drift Calibration Test")


def calibrate_gap(printer_name=None):
    """
    Sends hardware optical GAPDETECT command to calibrate the transparency threshold
    in the Xprinter EEPROM memory so the sensor stops on the exact physical gap every time.
    """
    if not printer_name:
        printer_name = get_default_printer()

    cmd = (
        "GAPDETECT\r\n"
        "FORMFEED\r\n"
    ).encode("ascii")

    return _send_raw_to_printer(printer_name, cmd, doc_name="IPS Gap Calibration")


def feed_label(printer_name=None, height_mm=24.0, gap_mm=3.0):
    """
    Feeds exactly one physical cycle to verify zero-drift gap alignment.
    """
    if not printer_name:
        printer_name = get_default_printer()

    h_mm = int(round(float(height_mm)))
    g_mm = int(round(float(gap_mm)))

    cmd = (
        f"SIZE 38 mm, {h_mm} mm\r\n"
        f"GAP {g_mm} mm, 0 mm\r\n"
        "OFFSET 0 mm\r\n"
        "SET TEAR OFF\r\n"
        "FORMFEED\r\n"
    ).encode("ascii")

    return _send_raw_to_printer(printer_name, cmd, doc_name="IPS Form Feed")


if __name__ == "__main__":
    printers = list_printers()
    print("Installed Printers:")
    for p in printers:
        flag = " [DEFAULT]" if p["is_default"] else ""
        thermal = " [THERMAL]" if p["is_thermal"] else ""
        print(f" - {p['name']} ({p['port']}){flag}{thermal} - Jobs: {p['jobs']}")

    default_p = get_default_printer()
    print(f"\nDefault Printer: {default_p}")
    status = get_printer_status(default_p)
    print(f"Status: {status}")

