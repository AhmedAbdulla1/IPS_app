"""
test_with_driver_settings.py
----------------------------
اختبار طباعة ملصق واحد 38x12 مم بعد ضبط إعدادات تعريف الويندوز
مع تفعيل خروج الورقة للأمام (SET TEAR ON) لتراها وتنزعها بسهولة أمام عينيك.
"""

import ctypes
from ctypes import wintypes
import sys
import os
import io
from PIL import Image

class DOC_INFO_1(ctypes.Structure):
    _fields_ = [
        ("pDocName", wintypes.LPCWSTR),
        ("pOutputFile", wintypes.LPCWSTR),
        ("pDatatype", wintypes.LPCWSTR),
    ]

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

def test_print(node_id="101", floor="GF", printer_name=None, logo_path=r"firmware\tools\logo.svg"):
    if not printer_name:
        printer_name = get_default_printer()

    print(f"==================================================")
    print(f" جاري إرسال ملصق اختباري 38x12 مم إلى: {printer_name}")
    print(f" إعدادات الخروج: SET TEAR ON (تقديم الورقة لمسطرة الخروج لتراها وتنزعها)")
    print(f"==================================================")

    winspool = ctypes.WinDLL("winspool.drv")

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
        print(f"❌ تعذر فتح الطابعة!")
        return False

    try:
        doc_info = DOC_INFO_1()
        doc_info.pDocName = f"IPS Label Test {node_id}"
        doc_info.pOutputFile = None
        doc_info.pDatatype = "RAW"

        job_id = winspool.StartDocPrinterW(hPrinter, 1, ctypes.byref(doc_info))
        if job_id == 0:
            return False

        try:
            winspool.StartPagePrinter(hPrinter)

            # TSPL Commands for 38x12 mm
            header = (
                "SIZE 38 mm, 12 mm\r\n"
                "GAP 3 mm, 0 mm\r\n"
                "OFFSET 0 mm\r\n"
                "SET TEAR ON\r\n"
                "DIRECTION 1,0\r\n"
                "REFERENCE 0,0\r\n"
                "CLS\r\n"
                "BOX 8,8,272,95,2\r\n"
                f'TEXT 18,14,"2",0,1,1,"ID:{node_id}  FL:{floor}"\r\n'
                f'BARCODE 18,38,"128",30,1,0,2,2,"{node_id}"\r\n'
            )
            stream = bytearray(header.encode("utf-8"))

            logo_bytes, w_bytes, h_dots = get_logo_bitmap(logo_path, target_w=96, target_h=35, invert=True)
            if logo_bytes:
                stream.extend(f"BITMAP 170,44,{w_bytes},{h_dots},0,".encode("ascii") + logo_bytes + b"\r\n")

            stream.extend(b"PRINT 1,1\r\n")

            raw_bytes = bytes(stream)
            bytes_written = wintypes.DWORD(0)
            ok = winspool.WritePrinter(hPrinter, raw_bytes, len(raw_bytes), ctypes.byref(bytes_written))
            winspool.EndPagePrinter(hPrinter)
            winspool.EndDocPrinter(hPrinter)

            if ok and bytes_written.value > 0:
                print(f"✅ تم إرسال أمر الطباعة بنجاح (Job ID: {job_id})!")
                print(f"   - خرجت الورقة للأمام لتراها وتنزعها.")
                return True
            return False
        except Exception as ex:
            print(f"❌ استثناء: {ex}")
            winspool.EndDocPrinter(hPrinter)
            return False
    finally:
        winspool.ClosePrinter(hPrinter)

if __name__ == "__main__":
    nid = sys.argv[1] if len(sys.argv) > 1 else "101"
    fl = sys.argv[2] if len(sys.argv) > 2 else "GF"
    test_print(node_id=nid, floor=fl)
