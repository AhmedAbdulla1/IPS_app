@echo off
chcp 65001 >nul
title IPS Mesh Multi-Flasher Web UI
echo =======================================================
echo    ⚡ تشغيل واجهة الحرق المتزامن (ESP32 Multi-Flasher)
echo =======================================================
echo.
cd /d "%~dp0"
python flasher_web_server.py
pause
