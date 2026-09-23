"""
test_print.py
-------------
سكريبت لاختبار طابعة الباركود (Xprinter XP-246B) وطباعة ملصق نموذج تجريبي مباشرة
عبر بروتوكول TSPL و Windows Spooler API بدون الحاجة لأي مكتبات خارجية.
"""

import ctypes
from ctypes import wintypes
import sys
import time

class DOC_INFO_1(ctypes.Structure):
    _fields_ = [
        ("pDocName", wintypes.LPCWSTR),
        ("pOutputFile", wintypes.LPCWSTR),
        ("pDatatype", wintypes.LPCWSTR),
    ]

from PIL import Image
import os
import io

def get_default_printer():
    winspool = ctypes.WinDLL("winspool.drv")
    buf_len = wintypes.DWORD(0)
    winspool.GetDefaultPrinterW(None, ctypes.byref(buf_len))
    if buf_len.value > 0:
        buf = ctypes.create_unicode_buffer(buf_len.value)
        if winspool.GetDefaultPrinterW(buf, ctypes.byref(buf_len)):
            return buf.value
    return "Xprinter XP-246B"

def get_logo_bitmap(logo_path, target_w=96, target_h=35, threshold=160, invert=True):
    if not os.path.exists(logo_path):
        return None, 0, 0
    try:
        if logo_path.lower().endswith(".svg"):
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
        print(f"⚠️ فشل معالجة صورة اللوجو: {e}")
        return None, 0, 0

def print_sample_label(printer_name=None, width_mm=38, height_mm=12, node_id="101", floor="GF", copies=1, logo_path=r"firmware\tools\logo.svg"):
    if not printer_name:
        printer_name = get_default_printer()

    print(f"==================================================")
    print(f" جاري تجهيز وإرسال نموذج الطباعة إلى: {printer_name}")
    print(f" مقاس الملصق المرجعي: {width_mm}x{height_mm} مم (38x12 مم) | عدد الملصقات: {copies}")
    print(f" الهوامش: 1 مم من الأعلى | 0 مم من الأسفل")
    if logo_path and os.path.exists(logo_path):
        print(f" إدراج اللوجو من: {logo_path}")
    print(f"==================================================")

    winspool = ctypes.WinDLL("winspool.drv")

    # Prototypes
    winspool.OpenPrinterW.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(wintypes.HANDLE), ctypes.c_void_p]
    winspool.OpenPrinterW.restype = wintypes.BOOL

    winspool.ClosePrinter.argtypes = [wintypes.HANDLE]
    winspool.ClosePrinter.restype = wintypes.BOOL

    winspool.StartDocPrinterW.argtypes = [wintypes.HANDLE, wintypes.DWORD, ctypes.POINTER(DOC_INFO_1)]
    winspool.StartDocPrinterW.restype = wintypes.DWORD

    winspool.EndDocPrinter.argtypes = [wintypes.HANDLE]
    winspool.EndDocPrinter.restype = wintypes.BOOL

    winspool.StartPagePrinter.argtypes = [wintypes.HANDLE]
    winspool.StartPagePrinter.restype = wintypes.BOOL

    winspool.EndPagePrinter.argtypes = [wintypes.HANDLE]
    winspool.EndPagePrinter.restype = wintypes.BOOL

    winspool.WritePrinter.argtypes = [wintypes.HANDLE, ctypes.c_char_p, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    winspool.WritePrinter.restype = wintypes.BOOL

    hPrinter = wintypes.HANDLE()
    if not winspool.OpenPrinterW(printer_name, ctypes.byref(hPrinter), None):
        print(f"❌ تعذر فتح الطابعة '{printer_name}'! تأكد من توصيل الكابل وتشغيل الطابعة.")
        return False

    try:
        doc_info = DOC_INFO_1()
        doc_info.pDocName = "IPS Sample Node Label 38x12 with Logo SVG"
        doc_info.pOutputFile = None
        doc_info.pDatatype = "RAW"

        job_id = winspool.StartDocPrinterW(hPrinter, 1, ctypes.byref(doc_info))
        if job_id == 0:
            err = ctypes.GetLastError()
            print(f"❌ فشل إنشاء أمر الطباعة StartDocPrinterW (Error Code: {err})")
            return False

        try:
            winspool.StartPagePrinter(hPrinter)

            # TSPL Commands for 38x12 mm (203 DPI: 8 dots/mm)
            # Exact vertical coordinates of Job 49 (Top Y=8, Text Y=14, Barcode Y=38, Logo Y=44, Bottom Y=95)
            # Width constrained to 34 mm surface (X: 8 to 272 dots), leaving 4 mm empty on right
            tspl_header = (
                f"SIZE {width_mm} mm, {height_mm} mm\r\n"
                f"GAP 3 mm, 0 mm\r\n"
                f"OFFSET 0 mm\r\n"
                f"SET TEAR OFF\r\n"
                f"DIRECTION 1,0\r\n"
                f"REFERENCE 0,0\r\n"
                f"CLS\r\n"
                f"BOX 8,8,272,95,2\r\n"
                f'TEXT 18,14,"2",0,1,1,"ID:{node_id}  FL:{floor}"\r\n'
                f'BARCODE 18,38,"128",30,1,0,2,2,"{node_id}"\r\n'
            )

            raw_bytes = bytearray(tspl_header.encode("utf-8"))

            # Append Logo BITMAP (width 96 dots, X=170 to 266, Y=44 to 79)
            if logo_path and os.path.exists(logo_path):
                logo_bytes, w_bytes, h_dots = get_logo_bitmap(logo_path, target_w=96, target_h=35, invert=True)
                if logo_bytes:
                    bitmap_cmd = f"BITMAP 170,44,{w_bytes},{h_dots},0,".encode("ascii") + logo_bytes + b"\r\n"
                    raw_bytes.extend(bitmap_cmd)

            raw_bytes.extend(f"PRINT {copies},1\r\n".encode("ascii"))
            bytes_written = wintypes.DWORD(0)

            ok = winspool.WritePrinter(hPrinter, bytes(raw_bytes), len(raw_bytes), ctypes.byref(bytes_written))
            winspool.EndPagePrinter(hPrinter)
            winspool.EndDocPrinter(hPrinter)

            if ok and bytes_written.value > 0:
                print(f"✅ تم إرسال أمر طباعة النموذج بنجاح!")
                print(f"   - رقم أمر الطباعة (Job ID): {job_id}")
                print(f"   - حجم البيانات المرسلة: {bytes_written.value} بايت")
                print(f"   - المحتوى: ID:{node_id}  FL:{floor} مع الباركود ولوجو SVG")
                return True
            else:
                print(f"❌ تم فتح الأمر لكن لم يتم كتابة البيانات بالطابعة.")
                return False

        except Exception as ex:
            print(f"❌ استثناء أثناء إرسال البيانات: {ex}")
            winspool.EndDocPrinter(hPrinter)
            return False

    finally:
        winspool.ClosePrinter(hPrinter)

def print_batch_labels(printer_name=None, width_mm=38, height_mm=12, start_id=100, count=20, floor="GF", logo_path=r"firmware\tools\logo.svg"):
    if not printer_name:
        printer_name = get_default_printer()

    print(f"==================================================")
    print(f" جاري تجهيز وإرسال دفعة طباعة إلى: {printer_name}")
    print(f" عدد الملصقات: {count} ملصق متتالي (من ID:{start_id} إلى ID:{start_id + count - 1})")
    print(f" مقاس الملصق: {width_mm}x{height_mm} مم")
    print(f"==================================================")

    winspool = ctypes.WinDLL("winspool.drv")

    hPrinter = wintypes.HANDLE()
    if not winspool.OpenPrinterW(printer_name, ctypes.byref(hPrinter), None):
        print(f"❌ تعذر فتح الطابعة '{printer_name}'!")
        return False

    try:
        doc_info = DOC_INFO_1()
        doc_info.pDocName = f"IPS Batch Labels {start_id}-{start_id + count - 1}"
        doc_info.pOutputFile = None
        doc_info.pDatatype = "RAW"

        job_id = winspool.StartDocPrinterW(hPrinter, 1, ctypes.byref(doc_info))
        if job_id == 0:
            err = ctypes.GetLastError()
            print(f"❌ فشل إنشاء أمر الطباعة StartDocPrinterW (Error Code: {err})")
            return False

        try:
            winspool.StartPagePrinter(hPrinter)

            # Pre-render logo bitmap data once
            logo_bitmap_data = None
            w_bytes = 0
            h_dots = 0
            if logo_path and os.path.exists(logo_path):
                logo_bitmap_data, w_bytes, h_dots = get_logo_bitmap(logo_path, target_w=96, target_h=35, invert=True)

            # Global TSPL header configured for the physical 24 mm twin-label pitch (2 stickers x 12mm)
            # OFFSET 0 mm and SET TEAR OFF ensures the printer never advances 2.5 mm into the next pair!
            stream = bytearray()
            stream.extend(
                f"SIZE {width_mm} mm, 24 mm\r\n"
                f"GAP 3 mm, 0 mm\r\n"
                f"OFFSET 0 mm\r\n"
                f"SET TEAR OFF\r\n"
                f"DIRECTION 1,0\r\n"
                f"REFERENCE 0,0\r\n".encode("utf-8")
            )

            # Process in pairs (Sticker 1 at Y=0..96, Sticker 2 at Y=96..192)
            for i in range(0, count, 2):
                id1 = start_id + i
                id2 = start_id + i + 1 if (i + 1 < count) else None

                # Clear image buffer for this 24 mm physical label
                stream.extend(b"CLS\r\n")

                # --- Sticker 1 (Top Half: 0 to 12 mm / dots 0 to 96) ---
                # Box from Y=6 to Y=88 (leaves safety margin before seam at Y=96)
                s1_tspl = (
                    f"BOX 8,6,272,88,2\r\n"
                    f'TEXT 18,12,"2",0,1,1,"ID:{id1}  FL:{floor}"\r\n'
                    f'BARCODE 18,34,"128",26,1,0,2,2,"{id1}"\r\n'
                )
                stream.extend(s1_tspl.encode("utf-8"))
                if logo_bitmap_data:
                    stream.extend(f"BITMAP 170,38,{w_bytes},{h_dots},0,".encode("ascii") + logo_bitmap_data + b"\r\n")

                # --- Sticker 2 (Bottom Half: 12 to 24 mm / dots 96 to 192) ---
                if id2 is not None:
                    # Offset all Y coordinates by exactly +96 dots (12 mm)
                    # Box from Y=102 to Y=184 (leaves safety margin before gap at Y=192)
                    s2_tspl = (
                        f"BOX 8,102,272,184,2\r\n"
                        f'TEXT 18,108,"2",0,1,1,"ID:{id2}  FL:{floor}"\r\n'
                        f'BARCODE 18,130,"128",26,1,0,2,2,"{id2}"\r\n'
                    )
                    stream.extend(s2_tspl.encode("utf-8"))
                    if logo_bitmap_data:
                        stream.extend(f"BITMAP 170,134,{w_bytes},{h_dots},0,".encode("ascii") + logo_bitmap_data + b"\r\n")

                # Print the complete 24 mm pair
                stream.extend(b"PRINT 1,1\r\n")

            bytes_written = wintypes.DWORD(0)
            raw_bytes = bytes(stream)
            ok = winspool.WritePrinter(hPrinter, raw_bytes, len(raw_bytes), ctypes.byref(bytes_written))
            winspool.EndPagePrinter(hPrinter)
            winspool.EndDocPrinter(hPrinter)
            return ok
        except Exception as ex:
            print(f"❌ استثناء: {ex}")
            winspool.EndDocPrinter(hPrinter)
            return False
    finally:
        winspool.ClosePrinter(hPrinter)

def test_pair(id1=100, id2=101, floor="GF", shift_dots=0, printer_name=None, logo_path=r"firmware\tools\logo.svg"):
    # Reverted to standard clean pair
    return print_sample_label(node_id=str(id1), copies=1)

if __name__ == "__main__":
    p_name = sys.argv[1] if len(sys.argv) > 1 else None
    print_sample_label(p_name)
