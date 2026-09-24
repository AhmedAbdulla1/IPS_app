#!/usr/bin/env bash
# ==============================================================================
# سكربت بناء ورفع تطبيق مجلس النواب لنظام iOS وربطه مع Shorebird Code Push
# يتم تشغيل هذا السكربت على جهاز الماك لإتمام عملية الرفع إلى Apple Developer
# ==============================================================================

set -e

echo "🚀 [1/6] بدء فحص بيئة العمل على جهاز الماك..."

# التحقق من تثبيت Homebrew
if ! command -v brew &> /dev/null; then
    echo "⚠️ Homebrew غير مثبت. يرجى تثبيته من https://brew.sh أو تشغيل الأمر:"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
fi

# التحقق من تثبيت CocoaPods
if ! command -v pod &> /dev/null; then
    echo "📦 تثبيت CocoaPods..."
    brew install cocoapods
else
    echo "✓ CocoaPods مثبت."
fi

# التحقق من تثبيت Shorebird CLI
if ! command -v shorebird &> /dev/null; then
    echo "🐦 تثبيت Shorebird CLI..."
    curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
    export PATH="$HOME/.shorebird/bin:$PATH"
else
    echo "✓ Shorebird CLI مثبت."
fi

echo ""
echo "🔍 [2/6] فحص تسجيل الدخول في Shorebird..."
shorebird doctor

echo ""
echo "📦 [3/6] تثبيت حزم Flutter و CocoaPods..."
flutter pub get
cd ios
pod install --repo-update
cd ..

echo ""
echo "🛠️ [4/6] بناء وإصدار التطبيق لنظام iOS عبر Shorebird (مع ضغط الحجم وفصل الرموز)..."
echo "تفعيل --split-debug-info و --obfuscate لتقليص حجم ملف الـ IPA بنسبة تصل إلى 40%"
shorebird release ios --split-debug-info=build/symbols --obfuscate

echo ""
echo "🎉 [5/6] اكتمل البناء بنجاح!"
echo "📁 ملف الـ IPA النهائي موجود في:"
echo "   $(pwd)/build/ios/ipa/*.ipa"

echo ""
echo "=============================================================================="
echo "🚀 [6/6] الخطوة التالية: رفع التطبيق إلى Apple Developer / TestFlight"
echo "=============================================================================="
echo "لديك طريقتان للرفع:"
echo "الطريقة الأولى (الأسهل والأسرع):"
echo "  افتح تطبيق Apple Transporter على الماك، واسحب ملف الـ .ipa إليه واضغط Deliver."
echo ""
echo "الطريقة الثانية (عبر Terminal مباشرة):"
echo '  xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios -u "YOUR_APPLE_ID" -p "APP_SPECIFIC_PASSWORD"'
echo ""
echo "=============================================================================="
echo "⚡ كيفية إرسال تحديثات فورية مستقبلاً (Code Push) بدون مراجعة أبل:"
echo "=============================================================================="
echo "في أي وقت تقوم فيه بتعديل أي كود في دارت (إصلاحات، شاشات، نصوص)، نفذ ببساطة:"
echo "  shorebird patch ios --split-debug-info=build/symbols --obfuscate"
echo "وسيصل التحديث مباشرة لجميع المستخدمين في غضون ثوانٍ!"
echo "=============================================================================="
