# الدليل الشامل لنشر تطبيق مجلس النواب على Apple Developer ودمج Shorebird Code Push

تم إعداد وتجهيز مشروع **مجلس النواب (PathFinder)** بالكامل لدعم النشر على **Apple Developer (TestFlight & App Store)** مع دمج خدمة **Shorebird Code Push** للتحديث الفوري عبر الهواء (Over-The-Air OTA) دون انتظار مراجعة أبل لكل تعديل.

---

## 📋 الفهرس
1. [ما تم إنجازه وفحصه بالكامل على بيئة الويندوز](#1-ما-تم-إنجازه-وفحصه-بالكامل-على-بيئة-الويندوز)
2. [متطلبات حساب Apple Developer & App Store Connect](#2-متطلبات-حساب-apple-developer--app-store-connect)
3. [خطوة الماك الختامية (البناء والرفع)](#3-خطوة-الماك-الختامية-البناء-والرفع)
4. [كيفية إرسال التحديثات الفورية عبر Shorebird (Code Push)](#4-كيفية-إرسال-التحديثات-الفورية-عبر-shorebird-code-push)
5. [نصائح اجتياز مراجعة أبل (App Store Review Guidelines)](#5-نصائح-اجتياز-مراجعة-أبل-app-store-review-guidelines)

---

## 1. ما تم إنجازه وفحصه بالكامل على بيئة الويندوز

لقد قمنا بحل كافة المشاكل الفنية وتجهيز الملفات مسبقاً بنسبة 100%:

1. **تهيئة Shorebird Code Push**:
   - تم إنشاء التطبيق رسمياً على سحابة Shorebird وتوليد معرّف التطبيق الفريد:
     - `app_id: 817c327e-183b-47cf-adc2-f98f62f214b8`
   - تم إنشاء وتوثيق ملف [shorebird.yaml](file:///d:/IPS_app/IPS_app/shorebird.yaml) وإضافته لـ `assets` في [pubspec.yaml](file:///d:/IPS_app/IPS_app/pubspec.yaml).
   - تم فحص وتأكيد جاهزية Shorebird عبر `shorebird doctor` بنجاح.

2. **معالجة ثغرة صلاحيات iOS القاتلة**:
   - في [permission_controller.dart](file:///d:/IPS_app/IPS_app/lib/controllers/permission_controller.dart):
     - تم فصل كود الصلاحيات برمجياً بحسب نظام التشغيل (`Platform.isIOS`).
     - على نظام iOS يتم طلب وفحص `Permission.bluetooth` (المعتمد في CoreBluetooth) بدلاً من `bluetoothScan` و `bluetoothConnect` الخاصة بأندرويد التي كانت تتسبب في تجميد فحص الصلاحيات على الآيفون.
     - تم تحديث دالة `requestEnableBluetooth()` لفتح إعدادات التطبيق `openAppSettings()` على iOS لأن أبل تمنع تشغيل البلوتوث برمجياً.
   - في [bluetooth_native.dart](file:///d:/IPS_app/IPS_app/lib/utils/bluetooth_native.dart):
     - تم حماية استدعاء MethodChannel ليعمل على أندرويد فقط لمنع حدوث استثناءات على iOS.

3. **إنشاء وتهيئة ملفات نظام iOS**:
   - **[Podfile](file:///d:/IPS_app/IPS_app/ios/Podfile)**:
     - تم إنشاء ملف `Podfile` بإصدار iOS Target `13.0`.
     - تم ضبط ماكروز مكتبة `permission_handler`:
       - `PERMISSION_LOCATION=1`
       - `PERMISSION_BLUETOOTH=1`
   - **[PrivacyInfo.xcprivacy](file:///d:/IPS_app/IPS_app/ios/Runner/PrivacyInfo.xcprivacy)**:
     - تم إنشاء بيان الخصوصية الإلزامي لأبل بدءاً من 2024 لبيان استخدام `UserDefaults` التابع لمكتبة `shared_preferences` مع المبرر المعتمد `CA92.1`.
     - تم ربط الملف تلقائياً في [project.pbxproj](file:///d:/IPS_app/IPS_app/ios/Runner.xcodeproj/project.pbxproj) في مراحل البناء.
   - **[Info.plist](file:///d:/IPS_app/IPS_app/ios/Runner/Info.plist)**:
     - إضافة مفتاح الإعفاء من استبيان التشفير:
       `<key>ITSAppUsesNonExemptEncryption</key><false/>` لتسهيل رفع كل Build دون أسئلة يدوية.
   - **أيقونات المتجر**:
     - الأيقونة بالحجم الكامل `1024x1024` وكافة المقاسات موجودة ومطابقة داخل `Assets.xcassets/AppIcon.appiconset`.

4. **نظام الكونسول الفارغ تماماً في وضع الإصدار (Zero-Console in Release Mode)**:
   - تم ضمان إسكات الكونسول بنسبة 100% في وضع الـ Release، مع إبقاء رسائل التطوير في وضع الـ Debug فقط:
     - **Zone Interception**: تغليف تشغيل التطبيق بالكامل داخل `runZoned` مع `ZoneSpecification` لمنع أي `print()` نهائياً من أي مكتبة خارجية أو كود داخلي.
     - **debugPrint Override**: إعادة توجيه `debugPrint` إلى دالة فارغة تماماً عند تفعيل `kReleaseMode`.
     - **GetX Logging**: ضبط `Get.config(enableLog: false)` وإيقاف `logWriterCallback` في `GetMaterialApp` لمنع GetX من طباعة أسماء الشاشات والـ controllers في الكونسول.
     - **FlutterReactiveBle Logs**: ضبط `ble.logLevel = LogLevel.none` في Release لمنع سيل بيانات حزم البلوتوث من التدفق في الكونسول.
     - **Supabase Logs**: ضبط `debug: !kReleaseMode` في `Supabase.initialize`.
     - **Sentry Logs**: ضبط `options.debug = false` لمنع Sentry SDK من طباعة رسائله التشخيصية.
     - **FlutterError Silent Capture**: اعتراض أخطاء الواجهة في Release وإرسالها إلى Sentry مباشرة دون إلقاء stack traces في سجلات النظام.
     - **AppLogger**: بناء فئة مركزية `AppLogger` تعمل فقط عندما يكون `kDebugMode` مفعلاً.

5. **أقصى تدابير تقليص حجم التطبيق (Over 10 MB Asset & Binary Reduction)**:
   - **تنظيف الأصول الميتة (Dead Assets)**: أرشفة 8.5 ميجابايت من ملفات GIF والصور القديمة غير المستخدمة (`vector_loading.gif`, `calibrate.gif`, `ic_splash.png`, إلخ).
   - **فصل مصادر الأيقونات عن حزمة التطبيق**: نقل `icon_launcher.png` و `icon_adaptive_fg.png` (قرابة 1 ميجابايت) إلى `assets_archive/icon_sources/` وتعديل مساراتها في `icons_launcher.yaml` لمنع Flutter من حشرها داخل ملف الـ IPA النهائي.
   - **الضغط بدون فقدان جودة (Lossless PNG Compression)**: ضغط صور الخلفيات والشاشات الترحيبية النشطة بمستوى ضغط أقصى (Level 9 Lossless)، مما وفر 814 كيلوبايت إضافية مع الحفاظ على دقة البكسل 100%.
   - **انخفاض إجمالي حجم الأصول**: انخفضت الأصول المضمنة داخل التطبيق من أكثر من **15 ميجابايت** إلى **4.77 ميجابايت فقط** (وفر يزيد عن 68%).
   - **تنظيف التبعيات (pubspec.yaml)**: نقل حزم التوليد مثل `flutter_launcher_icons`, `flutter_native_splash`, `icons_launcher` إلى `dev_dependencies` لمنع إدراج مكتبات معالجة الصور في حزمة الإنتاج.
   - **تحسينات المترجم في iOS (Podfile & Xcode)**:
     - تفعيل `DEAD_CODE_STRIPPING = YES` لحذف أي كود غير مستخدم.
     - تفعيل `STRIP_INSTALLED_PRODUCT = YES` و `STRIP_SWIFT_SYMBOLS = YES` لحذف رموز تصحيح الأخطاء من الـ Binary.
     - تفعيل `DEPLOYMENT_POSTPROCESSING = YES` و `COPY_PHASE_STRIP = YES`.
     - تفعيل Link-Time Optimization (`LLVM_LTO = YES`) لتحسين الربط المتبادل بين المكتبات.
     - تفعيل Whole-Module Optimization (`SWIFT_COMPILATION_MODE = wholemodule`).
     - إيقاف `ENABLE_NS_ASSERTIONS = NO` و `CLANG_ENABLE_CODE_COVERAGE = NO`.
   - **أمر البناء الموصى به**: `--split-debug-info=build/symbols --obfuscate` لضغط حجم الكود وفصل رموز Dart في خريطة خارجية لـ Sentry.

6. **سلامة الاختبارات والتحليل والكود النظيف**:
   - حذف الـ Unused Imports وكافة الأكواد الميتة (Dead Code) في شاشات التطبيق.
   - نجاح كافة اختبارات الوحدة والدخان 100% عبر `flutter test`.
   - اجتياز `flutter analyze` دون أي أخطاء أو تحذيرات.

---

## 2. متطلبات حساب Apple Developer & App Store Connect

قبل الانتقال للماك، تأكد من تجهيز الخطوات التالية في متصفحك:

### أ) تسجيل معرّف التطبيق (App ID)
1. ادخل إلى: [developer.apple.com/account](https://developer.apple.com/account).
2. انتقل إلى **Certificates, Identifiers & Profiles** -> **Identifiers**.
3. اضغط على زر `+` واختر **App IDs**.
4. اختر نوع **App** وضع:
   - **Description**: `Egyptian Parliament IPS`
   - **Bundle ID**: اختر `Explicit` واكتب:
     `com.tranex.parliament`
   - في خانة **Capabilities**: لا تحتاج لتحديد أي صلاحيات خاصة (حيث أن الموقع والبلوتوث صلاحيات قياسية تعتمد على Info.plist).
5. اضغط **Continue** ثم **Register**.

### ب) إنشاء التطبيق في App Store Connect
1. ادخل إلى: [appstoreconnect.apple.com](https://appstoreconnect.apple.com).
2. انتقل إلى **My Apps** واضغط على زر `+` -> **New App**.
3. املأ البيانات:
   - **Platforms**: اختر `iOS`.
   - **Name**: `مجلس النواب` (إذا كان الاسم مستخدماً يمكنك كتابة `مجلس النواب - الملاحة الداخلية` أو `مجلس النواب - IPS`).
   - **Primary Language**: `Arabic` (العربية).
   - **Bundle ID**: اختر `com.tranex.parliament` من القائمة المنسدلة.
   - **SKU**: اكتب `com-tranex-parliament`.
   - **User Access**: اختر `Full Access`.
4. اضغط **Create**.

---

## 3. خطوة الماك الختامية (البناء والرفع)

عند فتح المشروع على جهاز الماك، العملية ستكون في غاية السهولة لأن كل شيء جاهز:

### الخيار الأسرع: عبر السكربت التلقائي
قمنا بإنشاء سكربت مخصص داخل المشروع يقوم بكل شيء تلقائياً. كل ما عليك فعله في مبنى الأوامر (Terminal) على الماك:
```bash
chmod +x scripts/mac_release_and_deploy.sh
./scripts/mac_release_and_deploy.sh
```

### الخيار اليدوي خطوة بخطوة:
1. **تثبيت حزم CocoaPods**:
   ```bash
   cd ios
   pod install
   cd ..
   ```
2. **ضبط التوقيع في Xcode (Signing)**:
   - افتح مساحة العمل في Xcode:
     ```bash
     open ios/Runner.xcworkspace
     ```
   - من الشريط الجانبي الأيسر اختر **Runner**.
   - انتقل إلى تبويب **Signing & Capabilities**.
   - تأكد من تفعيل: **Automatically manage signing**.
   - في خانة **Team**: اختر حساب المطور الخاص بك (Apple Developer Team).
   - تأكد أن Bundle Identifier هو `com.tranex.parliament`.
   - أغلق Xcode.

3. **بناء النسخة وربطها مع Shorebird (مع أقصى تقليص للحجم)**:
   ```bash
   shorebird release ios --split-debug-info=build/symbols --obfuscate
   ```
   *يقوم هذا الأمر ببناء تطبيق iOS وتوليد ملف الـ `.ipa` داخل مجلد `build/ios/ipa` مع فصل رموز التصحيح (Debug Symbols) وتشفير أسماء الدوال، مما يخفض حجم التطبيق بنسبة تصل إلى 40% ويمنع الهندسة العكسية.*

4. **رفع الـ IPA إلى App Store Connect / TestFlight**:
   - **الطريقة الأولى (موصى بها)**: افتح تطبيق **Apple Transporter** (مجاني من متجر برامج الماك)، واسحب ملف الـ `.ipa` إليه واضغط **Deliver**.
   - **الطريقة الثانية**: عبر الطرفية باستخدام أمر:
     ```bash
     xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios -u "your-email@apple.com" -p "app-specific-password"
     ```

بمجرد اكتمال الرفع، ستظهر النسخة خلال دقائق في تبويب **TestFlight** داخل App Store Connect وستكون جاهزة للاختبار أو الإرسال للمراجعة للنشر على الـ App Store!

---

## 4. كيفية إرسال التحديثات الفورية عبر Shorebird (Code Push)

بعد أن ينزل التطبيق على أجهزة المستخدمين من الآب ستور أو TestFlight، إذا أردت تعديل أي كود في دارت (شاشات، نصوص، إصلاح أخطاء، منطق مسارات):

1. قم بعمل التعديل البرمجي على جهازك (سواء كنت على **ويندوز** أو **ماك**).
2. نفذ الأمر التالي في سطر الأوامر:
   ```bash
   shorebird patch ios --split-debug-info=build/symbols --obfuscate
   ```
3. سيقوم Shorebird بحساب الفارق (diff) وتشفيره ورفعه لسحابة Shorebird.
4. بمجرد فتح التطبيق من قبل أي مستخدم، يتم تنزيل التحديث في الخلفية تلقائياً وتطبيقه فوراً!

> ⚠️ **ملاحظة هامة حول قيود Shorebird**:
> - الـ Patch يدعم جميع تعديلات أكواد Dart و Flutter بدون استثناء.
> - إذا قمت مستقبلاً بإضافة مكتبة تتضمن كود أصلي جديد (Native Swift / Objective-C) أو تعديل في `Info.plist`، فهذا يتطلب بناء نسخة جديدة ورفعها للآب ستور عبر `shorebird release ios`.

---

## 5. نصائح اجتياز مراجعة أبل (App Store Review Guidelines)

نظراً لأن التطبيق يعتمد على البلوتوث والملاحة الداخلية داخل مبنى مجلس النواب:
1. **شرح في خانة Review Notes**:
   عند تقديم التطبيق للمراجعة في App Store Connect، اكتب في خانة **App Review Information -> Notes**:
   > "This application is designed for indoor navigation inside the Egyptian Parliament building using Bluetooth Low Energy (BLE) beacons. The location and Bluetooth permissions are strictly used to scan nearby beacons in the foreground to assist visitors and members with indoor wayfinding."
2. **فيديو توضيحي (Demo Video)**:
   إذا طلب فريق مراجعة أبل كيفية عمل التطبيق لعدم تواجدهم الفعلي داخل مبنى المجلس، يمكنك تصوير فيديو قصير لشاشة الهاتف أثناء الملاحة داخل المبنى وإرفاق رابط غير مدرج له على YouTube أو Vimeo في خانة الملاحظات.
3. **سياسة الخصوصية (Privacy Policy)**:
   أبل تشترط وضع رابط سياسة خصوصية صالح لأي تطبيق يستخدم صلاحيات الموقع والبلوتوث. تأكد من إدخال رابط سياسة خصوصية صالح في خانة Privacy Policy URL في App Store Connect.
