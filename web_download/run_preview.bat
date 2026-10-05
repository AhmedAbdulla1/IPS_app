@echo off
chcp 65001 >nul
title معاينة صفحة تحميل تطبيق مسار
echo ========================================================
echo    🚀 تشغيل صفحة تحميل تطبيق مسار (APK Download Page)
echo ========================================================
echo.
echo  يتم الآن تشغيل السيرفر المحلي على: http://localhost:8080
echo  اضغط Ctrl + C لإيقاف السيرفر في أي وقت.
echo.
start http://localhost:8080
python -m http.server 8080
pause
