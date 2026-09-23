"""
calibrate_gap.py
----------------
إرسال أمر المعايرة التلقائية لحساس الفاصل (GAPDETECT) إلى طابعة Xprinter XP-246B.
ستقوم الطابعة بسحب عدة ملصقات لقياس شفافية الفاصل (2-3 مم) بدقة وتعيين جهد الحساس
وحفظه في الذاكرة لتتعرف على الفاصل في كل ضغطة FEED وفي كل طباعة.
"""

import ctypes
from ctypes import wintypes
import time

class DOC_INFO_1(ctypes.Structure):
    _fields_ = [
        ("pDocName", wintypes.LPCWSTR),
        ("pOutputFile", wintypes.LPCWSTR),
        ("pDatatype", wintypes.LPCWSTR),
    ]

def calibrate_gap_sensor(printer_name="Xprinter XP-246B"):
    print(f"==================================================")
    print(f" جاري إرسال أمر المعايرة التلقائية (GAPDETECT) إلى: {printer_name}")
    print(f" ستقوم الطابعة بسحب عدة ملصقات لمعايرة حساسية الضوء ثم تقف عند الفاصل.")
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
        doc_info.pDocName = "Auto Gap Calibration"
        doc_info.pOutputFile = None
        doc_info.pDatatype = "RAW"

        job_id = winspool.StartDocPrinterW(hPrinter, 1, ctypes.byref(doc_info))
        if job_id == 0:
            return False

        try:
            winspool.StartPagePrinter(hPrinter)
            
            # TSPL GAPDETECT command:
            # Feeds paper, samples optical voltage at gap vs label, stores threshold to EEPROM
            cmds = "GAPDETECT\r\n"
            raw_bytes = cmds.encode("ascii")
            bytes_written = wintypes.DWORD(0)

            ok = winspool.WritePrinter(hPrinter, raw_bytes, len(raw_bytes), ctypes.byref(bytes_written))
            winspool.EndPagePrinter(hPrinter)
            winspool.EndDocPrinter(hPrinter)

            if ok and bytes_written.value > 0:
                print(f"✅ تم إرسال أمر المعايرة التلقائية (GAPDETECT) بنجاح!")
                print(f"   - الطابعة تقوم الآن بقياس الفاصل وحفظ الإعدادات تلقائياً.")
                return True
        except Exception as ex:
            print(f"❌ استثناء: {ex}")
            winspool.EndDocPrinter(hPrinter)
            return False
    finally:
        winspool.ClosePrinter(hPrinter)

if __name__ == "__main__":
    calibrate_gap_sensor()
