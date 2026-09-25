@echo off
setlocal

echo ========================================================
echo   Building Android App Bundle (.aab) for Google Play
echo ========================================================
echo.

cd /d "%~dp0\.."

if not exist "android\key.properties" (
    echo [WARNING] android\key.properties not found!
    echo The bundle will be built with debug signing (rejected by Play Store).
    echo Please run scripts\generate_android_keystore.bat first to set up release signing!
    echo.
    set /p PROCEED="Do you still want to proceed with debug signing for testing? (y/N): "
    if /i not "%PROCEED%"=="y" (
        exit /b 1
    )
)

echo Cleaning previous builds...
call flutter clean
call flutter pub get

echo.
echo Building Release App Bundle...
call flutter build appbundle --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo [SUCCESS] App Bundle built successfully!
    echo Output location:
    echo build\app\outputs\bundle\release\app-release.aab
    echo ========================================================
    echo.
    explorer /select,"build\app\outputs\bundle\release\app-release.aab"
) else (
    echo.
    echo [ERROR] Build failed! Check the error logs above.
)

pause
