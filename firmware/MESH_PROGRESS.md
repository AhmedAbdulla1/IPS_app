# Mesh Health Monitoring - Progress Tracking

مرجع تتبع تنفيذ شبكة مراقبة صحة النودز. راجع `MESH_DESIGN.md` للتصميم الكامل.

**قرار الأدوات المعتمد:** ESP-IDF + ESP-MESH-LITE الرسمي. الفيرموير كله
(Root وNode) ESP-IDF native - مفيش Arduino خالص.

**pc_health_service:** Dart CLI.

---

## 🎉 حالة البناء والتشغيل

| المشروع | Build | اختبار هاردوير | Heartbeat raw msg |
|---|---|---|---|
| `IPS_Mesh_Node` | ✅ | ✅ (BLE + provisioning شغالين) | ✅ إرسال متكامل |
| `IPS_Mesh_Root` | ✅ | ✅ (mesh_lite level=0 اشتغل) | ✅ استقبال متكامل |

---

## ✅ TODOs الحرجة اللي خلصت

1. **API إرسال/استقبال الـheartbeat** - اتأكد من `esp_mesh_lite_core.h`
   الحقيقي وكوده متكامل:
   - Node: `esp_mesh_lite_send_msg(ESP_MESH_LITE_RAW_MSG, &conf)` مع
     `raw_resend = esp_mesh_lite_send_raw_msg_to_root`
   - Root: `esp_mesh_lite_raw_msg_action_list_register()` مع callback
     بيفك `ips_health_heartbeat_t` (24 بايت: node_id[16] + seq + hop_count
     + reserved + uptime_ms) ويحدّث `health_table`
   - الـstruct وmsg_id (`0x1001`) متطابقين حرفيًا بين `IPS_Mesh_Node/main/config.h`
     و`IPS_Mesh_Root/main/config.h`
2. **BLE/WiFi Coexistence** - تأكدنا فعليًا من الـ`sdkconfig` المولّد (مش
   مجرد افتراض) إن `CONFIG_ESP_COEX_ENABLED=y` و`CONFIG_ESP_COEX_SW_COEXIST_ENABLE=y`
   فعلاً مفعّلين تلقائيًا بمجرد وجود `bt` و`esp_wifi` مع بعض في
   نفس البناء - مفيش حاجة لconfig يدوي إضافي. **متأكد من الإعداد،
   لسه محتاج اختبار أداء ميداني** (هل BLE advertising بيستقر لما
   mesh traffic يزيد؟).
3. **Root election** - اتأكد إنه مفيش حقل صريح "أنا Root" في mesh_lite -
   بيتحدد بالانتخاب الطبيعي، ومؤكد شغال من لوج تشغيل حقيقي (level=0)

## ⚠️ مفعّل بس لسه محتاج قرار - مش جاهز للنشر

- **مفتاح AES** - `esp_mesh_lite_aes_set_key()` مفعّل فعليًا في المشروعين
  (متطابقين) بمفتاح **لسه placeholder** (`IPS_mesh_lite_01` بالASCII) -
  موجود حرفيًا في `mesh_participant.c` و`mesh_bridge.c`. لازم يتستبدل
  بمفتاح عشوائي حقيقي قبل أي نشر فعلي (مش مجرد سيكريت في git -
  مبنى المجلس نفسه).

---

## حل مشاكل حقيقية ظهرت وقت الاختبار على هاردوير

1. **Crash - stack overflow في "Tmr Svc" task** → `CONFIG_FREERTOS_TIMER_TASK_STACK_DEPTH`
   اتزود من 2048 لـ4096 (في المشروعين)
2. **Root اتصل بشبكة WiFi حقيقية تلقائيًا** (SSID/password متخزنين من
   استخدام سابق للشريحة) - ده عكس التصميم (الشبكة لازم تكون معزولة عن
   الإنترنت) → `CONFIG_BRIDGE_EXTERNAL_NETIF_STATION` اتقفلت (في المشروعين)

---

## داشبورد العرض المحلي - ✅ اتبنى

**قرار 2026-09-12 النهائي:** الـheartbeat/الحالة الحية بتفضل محلية
على اللابتوب بس - مفيش Supabase خالص. اتبنى dashboard محلي جوه
`pc_health_service` نفسه:

- `lib/local_dashboard_server.dart` - سيرفر HTTP محلي
  (`127.0.0.1:8787` بس، مفيش اتصال برة الجهاز) بيعرض جدول
  النودز (Online/Offline، hop_count، آخر ظهور، الـtimeout المحسوب) -
  HTML/CSS/JS مُضمّنة في الكود نفسه (مفيش asset bundling)، بتتحدث
  بيعمل fetch لـ`/api/health` كل ثانية
- `lib/browser_launcher.dart` - بتفتح الداشبورد في نافذة "تطبيق"
  مستقلة (`--app=`) بدل تاب متصفح عادي - جرّب Edge الأول بعدين
  Chrome، ولو فشلت الاتنين بتطبع الرابط في الترمينال
- `bin/health_service.dart` - اتعدّل بالكامل: شال ربط Supabase من الـ
  main flow، بقى بيشغّل الداشبورد ويفتحه تلقائيًا وقت التشغيل
- `lib/supabase_uploader.dart` **لسه موجود في المشروع بس مش مستدعي**
  (محفوظ للرجوع لو رفع سحابي اتطلب لاحقًا)

**⚠️ لسه محتاج اختبار فعلي على هاردوير** (Root متوصل فعليًا
بالسيريال وبيبعت `HEALTH:` lines حقيقية).

---

## أداة provisioning (UID + إحداثيات) - تكتب في Supabase مباشرة

`firmware/tools/ips_node_provisioning_tool.html` - صفحة ويب (Edge/Chrome،
Web Serial API) للاستخدام الشخصي فقط على جهاز أحمد المحلي. الخطوات:

1. يدخل `node_id` (رقمي، يدوي حسب نظام الترقيم الخاص - مفيش
   auto-increment)، الدور (من dropdown مربوط بجدول `levels`، مع زرار
   لإضافة دور جديد لو محتاج)، X وY (إجباريين)، الاسم/النوع
   (اختياريين - قيم افتراضية لو فاضيين)
2. تولّد UID عشوائي محليًا (16 بايت)
3. تبعته `SET_ID:<hex>` للجهاز عبر Web Serial
4. تعمل INSERT مباشر في جدول `nodes` الحقيقي في Supabase (نفس
   الجدول المستخدم في الـFlutter app للـpathfinding) - `esp32_uuid` = الـUID
   المولّد
5. بتعرض حالة كل خطوة لوحدها (Serial ✅/❌ و_منفصل_ Supabase ✅/❌)،
   مع رسالة الخطأ الكاملة لو fail
6. سجل محلي + CSV export **احتياطي إضافي** (مش المصدر الأساسي
   بعد دلوقتي)

**قرارات معمارية اتحسمت (2026-09-12):**
- الصفحة بتكتب مباشرة بمفتاح `service_role` محفوظ في `localStorage`
  المتصفح بتاع أحمد بس - **قرار مقصود لأداة استخدام محلي
  شخصي بس**، ممنوع نشر/مشاركة الملف ده مع المفتاح محفوظ جواه
- `node_id` رقمي مش auto-increment (schema الحقيقي) - أحمد
  بيدخله يدوي كل مرة
- تم إضافة ميزة إضافة دور جديد (levels) من نفس الصفحة لأن جدول
  `levels` كان فاضي تمامًا وقت البناء

---

## هيكل المجلدات

```
firmware/
  IPS_Demo_Node_v2.0.0/     # الفيرموير القديم (Arduino) - مرجع بس
  IPS_Mesh_Node/            # ✅ يبني ويشتغل - ESP-IDF native (NimBLE + mesh_lite)
  IPS_Mesh_Root/            # ✅ يبني ويشتغل - ESP-IDF نضيف (mesh_lite root)
  pc_health_service/        # Dart CLI - Serial → Supabase (Skeleton كامل)
  tools/
    ips_node_provisioning_tool.html   # ✅ أداة UID + إحداثيات - مُختبرة
  MESH_DESIGN.md
  MESH_PROGRESS.md
  upload-all.ps1
```

---

## أولويات التنفيذ الجاية

1. **اختبار الداشبورد المحلي فعليًا على هاردوير** - Root متوصل بالسيريال +
   `dart run bin/health_service.dart` + تأكيد النافذة بتتحدث لما
   node يبعت heartbeat
2. **اختبار Root + Node مع بعض ميدانيًا أطول** - hop depth فعلي، RSSI
   بين نقاط متجاورة، ثبات BLE مع زيادة mesh traffic
3. **استبدال مفتاح الـAES** بمفتاح حقيقي (مش placeholder) قبل أي نشر
4. استمرار provisioning النودز الفعلية واحدة واحدة (أول واحدة تمت
   يدويًا مباشرة: node_id **107** "مدخل النواب" - `esp32_uuid` =
   `881324ae-02c6-0b9b-1c2e-c79f6d4d5ad2`)

## مشاكل/قرارات مفتوحة

- **طريقة نقل البيانات من Root للابتوب** - لسه مش مؤكدة نهائيًا،
  الافتراض العامل دلوقتي هو Serial/USB (موثق في MESH_DESIGN.md §4.7
  ومطبق فعليًا في `pc_health_service`)
- **auto-detect لمنفذ الـSerial في pc_health_service:** حاليًا ثابت في `.env`
