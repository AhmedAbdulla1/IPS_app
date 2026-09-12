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

1. **اختبار Root + Node مع بعض ميدانيًا** - تم فعليًا ✅ (`HEALTH:`
   lines طلعت على Serial بتاع الـRoot). لسه محتاج اختبار أداء
   أطول (hop depth فعلي، RSSI بين نقاط متجاورة، ثبات BLE مع
   زيادة mesh traffic)
2. **استبدال مفتاح الـAES** بمفتاح حقيقي (مش placeholder) قبل أي نشر
3. **ربط أداة الـprovisioning بـSupabase** - لما تتأكد الأعمدة، نضيف
   رفع مباشر بدل CSV اليدوي
4. Supabase migration لجدول `node_health` (SQL جاهز في MESH_DESIGN.md §7)
5. Dashboard للعرض - مكانه لسه مش محدد

## مشاكل/قرارات مفتوحة

- **تغيير معماري مهم (2026-09-12): الـheartbeat/الحالة الحية مش هترفع
  Supabase خالص.** القرار الجديد: online/offline + hop_count + last_seen
  تفضل **محلية على اللابتوب** (الـRoot ينقلها للابتوب بطريقة لسه
  مش متحددة - الافتراض الأصلي كان Serial/USB زي الموثق في
  MESH_DESIGN.md §4.7، لسه مش مؤكد نهائي)، واللابتوب هو اللي بيعرضها.
  **مفيش جدول `node_health` في Supabase** - الSQL المقترح في
  MESH_DESIGN.md §7 مُلغي.
  - ⚠️ **هذا يعارض كود موجود بالفعل**: `pc_health_service/lib/supabase_uploader.dart`
    مكتوب ليرفع `node_health` لـSupabase - لسه محتاج يتشال أو
    يتستبدل بطريقة عرض محلية (مكان Dashboard لسه محدد - نفس
    النقطة المفتوحة تحت). `health_protocol.dart` و`node_health_table.dart`
    لسه صحيحين ومفيدين (parsing + in-memory state) - المشكلة في
    الـuploader بس.
- **مكان الـDashboard:** لسه مش متفق عليه - دلوقتي أهم لأنه هيحدد
  طريقة نقل البيانات من Root للابتوب (Serial المفترض الأصلي، أو
  حاجة تانية)
- **أعمدة جدول nodes في Supabase:** ✅ اتأكدت (موثقة فوق)، أداة
  الـprovisioning بقت تكتب فيها مباشرة
- **auto-detect لمنفذ الـSerial في pc_health_service:** حاليًا ثابت في `.env`
