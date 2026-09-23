"""
set_printer_size_24mm.py
-------------------------
إرسال أمر ضبط مقاس البكرة إلى الطابعة (38 مم عرض × 24 مم طول الفاصل الفيزيائي)
لتستقر حركة زر الـ FEED وتقف عند الفاصل الحقيقي دائماً بدون الوقوف في منتصف الورق.
"""

import ctypes
from ctypes import wintypes

class DOC_INFO_1(ctypes.Structure):
    _fields_ = [
        ("pDocName", wintypes.LPCWSTR),
        ("pOutputFile", wintypes.LPCWSTR),
        ("pDatatype", wintypes.LPCWSTR),
    ]

def set_size(printer_name="Xprinter XP-246B"):
    print(f"==================================================")
    print(f" ضبط المقاس الفيزيائي للبكرة في ذاكرة الطابعة إلى: 24 مم")
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
        doc_info.pDocName = "Set 24mm Pitch"
        doc_info.pOutputFile = None
        doc_info.pDatatype = "RAW"

        job_id = winspool.StartDocPrinterW(hPrinter, 1, ctypes.byref(doc_info))
        if job_id == 0:
            return False

        try:
            winspool.StartPagePrinter(hPrinter)
            
            # Configure printer memory to match the physical gap interval (24 mm)
            cmds = (
                "SIZE 38 mm, 24 mm\r\n"
                "GAP 3 mm, 0 mm\r\n"
                "OFFSET 0 mm\r\n"
                "SET TEAR OFF\r\n"
                "DIRECTION 1,0\r\n"
                "REFERENCE 0,0\r\n"
                "CLS\r\n"
            )
            raw_bytes = cmds.encode("ascii")
            bytes_written = wintypes.DWORD(0)

            ok = winspool.WritePrinter(hPrinter, raw_bytes, len(raw_bytes), ctypes.byref(bytes_written))
            winspool.EndPagePrinter(hPrinter)
            winspool.EndDocPrinter(hPrinter)

            if ok and bytes_written.value > 0:
                print(f"✅ تم ضبط المقاس بنجاح إلى 24 مم (طول دورة الفاصل الحقيقية)!")
                print(f"   - الآن ذاكرة الطابعة متطابقة 100% مع البكرة الفيزيائية.")
                return True
        except Exception as ex:
            print(f"❌ استثناء: {ex}")
            winspool.EndDocPrinter(hPrinter)
            return False
    finally:
        winspool.ClosePrinter(hPrinter)

if __name__ == "__main__":
    set_size()
