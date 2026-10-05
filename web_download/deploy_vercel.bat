@echo off
chcp 65001 >nul
title رفع صفحة التحميل إلى Vercel
echo ========================================================
echo    🚀 رفع صفحة تحميل تطبيق مسار إلى Vercel
echo ========================================================
echo.
cd /d "%~dp0"

echo [1/2] التحقق من تسجيل الدخول إلى Vercel...
call vercel whoami >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ⚠️  تحتاج لتسجيل الدخول أولاً في Vercel.
    echo    سيتم فتح المتصفح لتسجيل الدخول بحسابك (GitHub أو Email)...
    echo.
    call vercel login
)

echo.
echo [2/2] جاري الرفع والإنتاج (Deploy to Production)...
echo.
call vercel --prod --yes

echo.
echo ========================================================
echo    ✅ اكتمل الرفع! يمكنك نسخ الرابط الظاهر بالأعلى.
echo ========================================================
pause
