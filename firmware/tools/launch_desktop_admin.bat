@echo off
chcp 65001 >nul
title IPS Mesh Flasher & Provisioning Studio (Administrator)

:: -------------------------------------------------------------
:: Step 1: Self-Elevation to Super Administrator (UAC Prompt)
:: -------------------------------------------------------------
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ========================================================
    echo   ⚡ طلب صلاحيات المسؤول الكاملة (Super Administrator)...
    echo ========================================================
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:: -------------------------------------------------------------
:: Step 2: Set Working Directory & Environment
:: -------------------------------------------------------------
cd /d "%~dp0"
echo ========================================================
echo   ⚡ استوديو الحرق وتجهيز الـ Beacon وطباعة الباركود
echo   🛡️ وضع الصلاحيات الكاملة: Super Administrator (Windows)
echo ========================================================
echo.

:: -------------------------------------------------------------
:: Step 3: Check if Python Web Server is running on Port 8585
:: -------------------------------------------------------------
powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort 8585 -ErrorAction SilentlyContinue" >nul 2>&1
if %errorLevel% neq 0 (
    echo [i] تشغيل سيرفر الأجهزة والـ USB المباشر...
    start /b "" python flasher_web_server.py
    timeout /t 2 /nobreak >nul
) else (
    echo [✓] السيرفر شغال بالفعل ومتصل بالعتاد.
)

:: -------------------------------------------------------------
:: Step 4: Launch Native Desktop Window (Chrome / Edge App Mode)
:: -------------------------------------------------------------
echo [i] فتح الواجهة كنافذة ديسكتوب أصلية (Standalone Desktop Window)...

set "CHROME_PATH=C:\Program Files\Google\Chrome\Application\chrome.exe"
set "EDGE_PATH=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

if exist "%CHROME_PATH%" (
    start "" "%CHROME_PATH%" --app="http://localhost:8585" --window-size=1400,920 --window-position=80,40
    goto :Done
)

if exist "%EDGE_PATH%" (
    start "" "%EDGE_PATH%" --app="http://localhost:8585" --window-size=1400,920 --window-position=80,40
    goto :Done
)

:: Fallback to default browser
start "" "http://localhost:8585"

:Done
echo [✓] تم فتح الاستوديو بنجاح!
timeout /t 3 >nul
exit
