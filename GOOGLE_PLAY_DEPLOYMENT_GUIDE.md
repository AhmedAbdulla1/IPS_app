# الدليل الشامل لتجهيز ونشر تطبيق مجلس النواب على Google Play Console

تم إعداد وتجهيز تطبيق **مجلس النواب (parliament_ips)** بنسبة 100% للنشر على متجر **Google Play** بأعلى معايير الأمان والتوافق مع متطلبات جوجل الحديثة (API 34/35+ و Android App Bundle)، مع **الحفاظ الكامل والمطلق على إعدادات الـ iOS (App Store) دون المساس بها نهائياً**.

---

## 📋 الفهرس
1. [معلومات هوية التطبيق (App Identity)](#1-معلومات-هوية-التطبيق-app-identity)
2. [استلام وتفعيل الصلاحيات (Google Play Console Access)](#2-استلام-وتفعيل-الصلاحيات-google-play-console-access)
3. [توليد مفتاح التوقيع الرقمي (Release Keystore)](#3-توليد-مفتاح-التوقيع-الرقمي-release-keystore)
4. [بناء حزمة المتجر (App Bundle .aab)](#4-بناء-حزمة-المتجر-app-bundle-aab)
5. [متطلبات مراجعة جوجل بلاي والسياسات الإلزامية (Data Safety & Policies)](#5-متطلبات-مراجعة-جوجل-بلاي-والسياسات-الإلزامية-data-safety--policies)
6. [نشر التحديثات عبر Shorebird Code Push](#6-نشر-التحديثات-عبر-shorebird-code-push)

---

## 1. معلومات هوية التطبيق (App Identity)

عند إنشاء التطبيق لأول مرة على لوحة تحكم Google Play، هذه هي البيانات المعتمدة في المشروع:

| البيان | القيمة في المشروع | الملاحظات |
| :--- | :--- | :--- |
| **اسم التطبيق (App Name)** | `مجلس النواب` | محدد في [AndroidManifest.xml](file:///d:/IPS_app/IPS_app/android/app/src/main/AndroidManifest.xml) |
| **معرّف الحزمة (Package Name / Application ID)** | `com.tranex.parliament` | محدد في [build.gradle.kts](file:///d:/IPS_app/IPS_app/android/app/build.gradle.kts) (مطابق لـ iOS Bundle ID) |
| **اللغة الافتراضية (Default Language)** | العربية (`ar`) | يمكنك إضافة الإنجليزية كلغة ثانوية |
| **نوع التطبيق (App / Game)** | تطبيق (`App`) | |
| **حالة التطبيق (Free / Paid)** | مجاني (`Free`) | |
| **إصدار التطبيق (Version)** | `1.0.0 (Build 1)` | من [pubspec.yaml](file:///d:/IPS_app/IPS_app/pubspec.yaml) |

---

## 2. استلام وتفعيل الصلاحيات (Google Play Console Access)

عندما يقوم مالك الحساب بإضافتك كمطور/مسؤول نشر:

1. **الرابط المباشر للوحة:**
   🔗 [https://play.google.com/console](https://play.google.com/console)
2. **استقبال الدعوة:**
   * ستصلك رسالة على بريدك في **Gmail** بعنوان:
     `Invitation to access [اسم حساب المطور] on Google Play Console`
   * اضغط على زر **Accept invitation**.
3. **الدخول والتحقق:**
   * بعد تسجيل الدخول، تأكد من اختيار **Developer Account** الصحيح من القائمة المنسدلة في أعلى الواجهة.
   * تأكد من امتلاكك صلاحيات:
     * `Create and edit releases`
     * `Release apps to testing tracks`
     * `Release apps to production`
4. **المسارات المتاحة للرفع داخل Google Play:**
   * **Internal testing (الاختبار الداخلي):** **(موصى به كأول خطوة)** – الرفع فوري ولا يحتاج مراجعة من موظفي جوجل، ويصل للتجربة في دقائق عبر رابط خاص لقائمتك من المختبرين.
   * **Closed testing (الاختبار المغلق):** يحتاج مراجعة أولية ويتيح إشراك مستخدمين محددين.
   * **Production (الإنتاج العام):** نشر التطبيق رسمياً لعموم الجمهور على المتجر بعد مراجعة كاملة من جوجل.

---

## 3. توليد مفتاح التوقيع الرقمي (Release Keystore)

متجر Google Play **يرفض تماماً** رفع أي حزمة موقعة بـ Debug Keys. يتطلب المتجر توقيع الـ Release بـ Keystore خاص ومحمي.

### الطريقة السريعة بنقرة واحدة (جاهزة في المشروع):
قمنا ببرمجة سكريبت تلقائي في مجلد المشروع:
1. انقر مرتين لتشغيل الملف:
   [scripts/generate_android_keystore.bat](file:///d:/IPS_app/IPS_app/scripts/generate_android_keystore.bat)
2. سيقوم السكريبت بطلب كلمة مرور للمفتاح وبيانات الشهادة، ثم يولد لك تلقائياً:
   * مفتاح التوقيع: `android/upload-keystore.jks`
   * ملف الإعدادات السري: `android/key.properties`

### الطريقة اليدوية (عبر Terminal):
1. افتح PowerShell داخل مجلد `android/`:
   ```bash
   keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. انسخ النموذج [android/key.properties.example](file:///d:/IPS_app/IPS_app/android/key.properties.example) إلى `android/key.properties` واكتب داخله:
   ```properties
   storePassword=كلمة_المرور_التي_اخترتها
   keyPassword=كلمة_المرور_التي_اخترتها
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

> [!CAUTION]
> **احتفظ بنسخة احتياطية آمنة من ملف `upload-keystore.jks` وكلمة المرور!**
> إذا فُقد هذا المفتاح قبل تفعيل Google Play App Signing، فلن تتمكن من رفع أي تحديثات لهذا التطبيق نهائياً.
> الملف محمي ومستثنى تلقائياً في `.gitignore` لمنع رفعه بالخطأ إلى Git.

---

## 4. بناء حزمة المتجر (App Bundle .aab)

متجر Google Play يتطلب صيغة **AAB (Android App Bundle)** وليس APK التقليدي.

### الطريقة الأولى: بنقرة زر
قم بتشغيل السكريبت المرفق:
[scripts/build_play_store_bundle.bat](file:///d:/IPS_app/IPS_app/scripts/build_play_store_bundle.bat)

### الطريقة الثانية: عبر سطر الأوامر (Flutter Standard)
```bash
flutter build appbundle --release
```
* **مسار الملف الناتج:**
  `build\app\outputs\bundle\release\app-release.aab`

---

## 5. متطلبات مراجعة جوجل بلاي والسياسات الإلزامية (Data Safety & Policies)

أثناء إعداد التطبيق في لوحة **App content** في Google Play Console، يجب تعبئة الاستبيانات التالية بدقة لتفادي رفض التطبيق:

### أ) سياسة الخصوصية (Privacy Policy) - إلزامي 100%
* لأن التطبيق يستخدم إذن الموقع `ACCESS_FINE_LOCATION` وإذن البلوتوث `BLUETOOTH_SCAN`، تشترط جوجل وضع رابط مباشر لسياسة الخصوصية على موقع ويب عام.
* **النص المطلوب بيانه في السياسة:** يوضح أن التطبيق يستخدم إشارات منارات البلوتوث (BLE Beacons) وإحداثيات الموقع لحساب الملاحة الداخلية فقط داخل المبنى، ولا يتم بيع أو مشاركة أي بيانات موقع مع أطراف ثالثة.

### ب) نموذج أمان البيانات (Data Safety Section)
* **هل يجمع التطبيق بيانات؟** نعم (Location).
* **نوع الموقع:** تقريبي (Coarse) ودقيق (Fine).
* **هل يتم جمعها أم مشاركتها؟** "Collected" (مجمعة فقط لحساب الموقع داخل التطبيق)، و **"Not shared with third parties"** (لا يتم مشاركتها خارجياً).
* **الغرض:** App Functionality (وظائف التطبيق الرئيسية - الملاحة الداخلية).
* **التشفير:** "Data is encrypted in transit" (نعم عبر HTTPS / TLS عند الاتصال بـ Supabase/Sentry).
* **حذف البيانات:** توفير خيار أو آلية لطلب حذف أي بيانات مستخدم (إن وُجد تسجيل دخول).

### ج) سياسة التطبيقات الحكومية (Government Apps Policy) - هام جداً!
* لأن اسم التطبيق **"مجلس النواب"**:
  * طبقت جوجل منذ 2023 سياسة مشددة تمنع أي تطبيق يحمل اسم أو شعار جهة حكومية إلا بتقديم **خطاب تفويض رسمي (Government Authorization Document)**.
  * **الحل:**
    * إذا كان التطبيق مخصصاً كـ (Enterprise / Internal App): يمكن رفعه في مسار **Internal testing** أو استخدام **Google Play Private Apps** المخصص للمؤسسات.
    * إذا كان سيُنشر للعامة على المتجر: يجب أن يقوم الحساب المالك برفع مستند التفويض أو السجل الدال على العلاقة الرسمية مع مجلس النواب عند طلب جوجل ذلك في قسم `App Content -> Government apps`.

---

## 6. نشر التحديثات عبر Shorebird Code Push

مشروعك مهيأ بالفعل ومعرّف في Shorebird بـ `app_id: 817c327e-183b-47cf-adc2-f98f62f214b8`.

* **لإصدار أول نسخة للمتجر مع Shorebird:**
  ```bash
  shorebird release android
  ```
  هذا الأمر يولد ملف الـ AAB المدمج معه محرك التحديثات الفورية ويرفعه على منصة Shorebird.
* **لإرسال تحديث فوري لاحقاً (دون الحاجة لإعادة مراجعة جوجل):**
  ```bash
  shorebird patch android
  ```

---

## 7. تأكيد سلامة إعدادات iOS (App Store)

تمت مراجعة شجرة المشروع بالكامل والتأكد بنسبة 100% من:
* مجلد [ios/](file:///d:/IPS_app/IPS_app/ios) لم يطرأ عليه أي تغيير أو مساس.
* ملف [Podfile](file:///d:/IPS_app/IPS_app/ios/Podfile) وبيان الخصوصية [PrivacyInfo.xcprivacy](file:///d:/IPS_app/IPS_app/ios/Runner/PrivacyInfo.xcprivacy) ومفاتيح [Info.plist](file:///d:/IPS_app/IPS_app/ios/Runner/Info.plist) كما هي تماماً وفق الدليل المعتمد في [APPLE_DEPLOYMENT_AND_SHOREBIRD_GUIDE.md](file:///d:/IPS_app/IPS_app/APPLE_DEPLOYMENT_AND_SHOREBIRD_GUIDE.md).
