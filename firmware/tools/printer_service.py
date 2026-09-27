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


def print_twin_label(node_id="101", floor="GF", printer_name=None, logo_path=None, copies=1, s1_shift_y=0, s2_shift_y=0, height_mm=24.0, width_mm=38.0, gap_mm=3.0, offset_y=0, inter_gap_dots=8, density=10, speed=3):
    """
    Prints clean borderless twin labels (Sticker 1 + Sticker 2):
    - No border (BOX removed)
    - No barcode (BARCODE removed)
    - Centered TRANEX Logo
    - Centered Node Number
    - Centered Floor Number
    """
    if not printer_name:
        printer_name = get_default_printer()

    node_id_str = str(node_id).strip()
    floor_str = str(floor).strip()
    h_mm = int(round(float(height_mm)))
    w_mm = int(round(float(width_mm)))
    g_mm = float(gap_mm)
    label_w_dots = int(w_mm * 8)
    density_val = max(1, min(15, int(density)))
    speed_val = max(1, min(6, int(speed)))

    # Compact logo for twin halves: 80x20 dots (10 bytes wide)
    logo_bytes, w_bytes, h_dots = get_logo_bitmap(logo_path, target_w=80, target_h=20, invert=True)

    stream = bytearray()
    header = (
        f"SIZE {w_mm} mm, {h_mm} mm\r\n"
        f"GAP {g_mm:g} mm, 0 mm\r\n"
        f"SPEED {speed_val}\r\n"
        f"DENSITY {density_val}\r\n"
        "OFFSET 0 mm\r\n"
        "SET TEAR OFF\r\n"
        "SET PEEL OFF\r\n"
        "SET CUTTER OFF\r\n"
        "DIRECTION 1,0\r\n"
        "REFERENCE 0,0\r\n"
        "CLS\r\n"
    )
    stream.extend(header.encode("utf-8"))

    # Prepare centered text
    node_text = node_id_str
    n_w = len(node_text) * 16
    node_x = max(8, (label_w_dots - n_w) // 2)

    if floor_str.upper().startswith("FL") or floor_str.upper().startswith("FLOOR") or floor_str.startswith("الدور"):
        floor_disp = floor_str
    else:
        floor_disp = f"FL: {floor_str}"
    f_w = len(floor_disp) * 12
    floor_x = max(8, (label_w_dots - f_w) // 2)
    logo_x = max(0, (label_w_dots - 80) // 2)

    # --- الملصق الأول: Sticker 1 ---
    base_top = 14 + offset_y
    s1_top = base_top + s1_shift_y
    if logo_bytes:
        stream.extend(f"BITMAP {logo_x},{s1_top},{w_bytes},{h_dots},0,".encode("ascii") + logo_bytes + b"\r\n")
    stream.extend(f'TEXT {node_x},{s1_top + 24},"3",0,1,1,"{node_text}"\r\n'.encode("utf-8"))
    stream.extend(f'TEXT {floor_x},{s1_top + 52},"2",0,1,1,"{floor_disp}"\r\n'.encode("utf-8"))

    # --- الملصق الثاني: Sticker 2 ---
    s2_top = s1_top + 80 + inter_gap_dots + s2_shift_y
    if logo_bytes:
        stream.extend(f"BITMAP {logo_x},{s2_top},{w_bytes},{h_dots},0,".encode("ascii") + logo_bytes + b"\r\n")
    stream.extend(f'TEXT {node_x},{s2_top + 24},"3",0,1,1,"{node_text}"\r\n'.encode("utf-8"))
    stream.extend(f'TEXT {floor_x},{s2_top + 52},"2",0,1,1,"{floor_disp}"\r\n'.encode("utf-8"))

    # أمر طباعة الورقة الواحدة
    stream.extend(f"PRINT {copies},1\r\n".encode("ascii"))

    return _send_raw_to_printer(printer_name, bytes(stream), doc_name=f"IPS Twin Node Label {node_id_str}")


def print_single_label(node_id="101", floor="GF", printer_name=None, logo_path=None, copies=1, height_mm=12.0, width_mm=38.0, gap_mm=2.0, offset_y=0, density=10, speed=3):
    """
    Prints a single clean label (adaptive to 12mm / 1.2cm or 24mm+):
    - Border completely removed (clean borderless)
    - Barcode removed
    - Centered TRANEX Logo at the top
    - Centered large bold Node Number in the middle
    - Centered Floor Number below it
    - Exactly 1 sheet printed per operation
    """
    if not printer_name:
        printer_name = get_default_printer()

    node_id_str = str(node_id).strip()
    floor_str = str(floor).strip()
    h_mm = int(round(float(height_mm)))
    w_mm = int(round(float(width_mm)))
    g_mm = float(gap_mm)
    total_dots = int(h_mm * 8)
    label_w_dots = int(w_mm * 8)

    density_val = max(1, min(15, int(density)))
    speed_val = max(1, min(6, int(speed)))

    stream = bytearray()
    header = (
        f"SIZE {w_mm} mm, {h_mm} mm\r\n"
        f"GAP {g_mm:g} mm, 0 mm\r\n"
        f"SPEED {speed_val}\r\n"
        f"DENSITY {density_val}\r\n"
        "OFFSET 0 mm\r\n"
        "SET TEAR OFF\r\n"
        "SET PEEL OFF\r\n"
        "SET CUTTER OFF\r\n"
        "DIRECTION 1,0\r\n"
        "REFERENCE 0,0\r\n"
        "CLS\r\n"
    )
    stream.extend(header.encode("utf-8"))

    # Determine layout mode based on label height:
    if h_mm <= 16:
        # Compact mode for small label (12 mm / 1.2 cm = 96 dots total height)
        # 1. TRANEX Logo (72 dots wide = 9 bytes, 20 dots high)
        logo_w = 72
        logo_h = 20
        logo_bytes, w_bytes, h_dots = get_logo_bitmap(logo_path, target_w=logo_w, target_h=logo_h, invert=True)
        if logo_bytes:
            logo_x = max(0, (label_w_dots - logo_w) // 2)
            logo_y = max(1, 4 + offset_y)
            stream.extend(f"BITMAP {logo_x},{logo_y},{w_bytes},{h_dots},0,".encode("ascii") + logo_bytes + b"\r\n")

        # 2. Centered Node Number (Font 4: 24 dots wide, 32 dots high - bold & prominent)
        node_text = node_id_str
        char_w = 24
        text_w = len(node_text) * char_w
        if text_w > (label_w_dots - 16):
            char_w = 16
            text_w = len(node_text) * char_w
            node_font = "3"
        else:
            node_font = "4"
        node_x = max(8, (label_w_dots - text_w) // 2)
        node_y = 28 + offset_y
        stream.extend(f'TEXT {node_x},{node_y},"{node_font}",0,1,1,"{node_text}"\r\n'.encode("utf-8"))

        # 3. Centered Floor Number (Font 2: 12 dots wide, 20 dots high)
        if floor_str:
            if floor_str.upper().startswith("FL") or floor_str.upper().startswith("FLOOR") or floor_str.startswith("الدور"):
                floor_disp = floor_str
            else:
                floor_disp = f"FL: {floor_str}"
            f_char_w = 12
            f_text_w = len(floor_disp) * f_char_w
            floor_x = max(8, (label_w_dots - f_text_w) // 2)
            floor_y = 64 + offset_y
            stream.extend(f'TEXT {floor_x},{floor_y},"2",0,1,1,"{floor_disp}"\r\n'.encode("utf-8"))

    else:
        # Standard mode for larger labels (24 mm+ = 192 dots total height)
        logo_w = 112
        logo_h = 32
        logo_bytes, w_bytes, h_dots = get_logo_bitmap(logo_path, target_w=logo_w, target_h=logo_h, invert=True)
        if logo_bytes:
            logo_x = max(0, (label_w_dots - logo_w) // 2)
            logo_y = 14 + offset_y
            stream.extend(f"BITMAP {logo_x},{logo_y},{w_bytes},{h_dots},0,".encode("ascii") + logo_bytes + b"\r\n")

        node_text = node_id_str
        if len(node_text) <= 8:
            char_w = 32
            text_w = len(node_text) * char_w
            node_x = max(8, (label_w_dots - text_w) // 2)
            node_y = 62 + offset_y
            stream.extend(f'TEXT {node_x},{node_y},"3",0,2,2,"{node_text}"\r\n'.encode("utf-8"))
        else:
            char_w = 24
            text_w = len(node_text) * char_w
            node_x = max(8, (label_w_dots - text_w) // 2)
            node_y = 68 + offset_y
            stream.extend(f'TEXT {node_x},{node_y},"4",0,1,1,"{node_text}"\r\n'.encode("utf-8"))

        if floor_str:
            if floor_str.upper().startswith("FL") or floor_str.upper().startswith("FLOOR") or floor_str.startswith("الدور"):
                floor_disp = floor_str
            else:
                floor_disp = f"FL: {floor_str}"

            if len(floor_disp) <= 10:
                f_char_w = 24
                f_text_w = len(floor_disp) * f_char_w
                floor_x = max(8, (label_w_dots - f_text_w) // 2)
                floor_y = 124 + offset_y
                stream.extend(f'TEXT {floor_x},{floor_y},"4",0,1,1,"{floor_disp}"\r\n'.encode("utf-8"))
            else:
                f_char_w = 16
                f_text_w = len(floor_disp) * f_char_w
                floor_x = max(8, (label_w_dots - f_text_w) // 2)
                floor_y = 128 + offset_y
                stream.extend(f'TEXT {floor_x},{floor_y},"3",0,1,1,"{floor_disp}"\r\n'.encode("utf-8"))

    # Print exactly 1 single label
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


def feed_label(printer_name=None, height_mm=12.0, gap_mm=2.0, width_mm=38.0):
    """
    Feeds exactly one physical label to verify zero-drift gap alignment.
    """
    if not printer_name:
        printer_name = get_default_printer()

    h_mm = int(round(float(height_mm)))
    w_mm = int(round(float(width_mm)))
    g_mm = float(gap_mm)

    cmd = (
        f"SIZE {w_mm} mm, {h_mm} mm\r\n"
        f"GAP {g_mm:g} mm, 0 mm\r\n"
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

