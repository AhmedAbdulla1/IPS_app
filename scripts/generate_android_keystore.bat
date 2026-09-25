@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   Android Keystore Generator for Play Store
echo ========================================================
echo.

cd /d "%~dp0\..\android"

if exist "upload-keystore.jks" (
    echo [WARNING] upload-keystore.jks already exists in android/!
    set /p OVERWRITE="Do you want to overwrite it? (y/N): "
    if /i not "!OVERWRITE!"=="y" (
        echo Cancelled. Keystore was not changed.
        pause
        exit /b 0
    )
)

echo Generating new release keystore (upload-keystore.jks)...
echo.
echo Please enter passwords when prompted and answer certificate questions.
echo (Remember the password you choose - you will need it!)
echo.

keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to generate keystore. Ensure Java keytool is in your PATH.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] upload-keystore.jks created successfully!
echo.
set /p KEY_PASS="Enter the password you chose for keystore/alias: "

echo storePassword=%KEY_PASS%> key.properties
echo keyPassword=%KEY_PASS%>> key.properties
echo keyAlias=upload>> key.properties
echo storeFile=upload-keystore.jks>> key.properties

echo.
echo [SUCCESS] android/key.properties generated successfully!
echo You can now build release bundles using:
echo   flutter build appbundle --release
echo or with Shorebird:
echo   shorebird release android
echo.
pause
