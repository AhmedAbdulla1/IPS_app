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
2. **AES encryption** - `esp_mesh_lite_aes_set_key()` مُفعّل في المشروعين
   (مفتاح placeholder مؤقت 16 بايت - **لازم يتغير قبل أي نشر فعلي**،
   نفس المفتاح لازم يفضل متطابق بين Root وNode)
3. **Root election** - اتأكد إنه مفيش حقل صريح "أنا Root" في mesh_lite -
   بيتحدد بالانتخاب الطبيعي، ومؤكد شغال من لوج تشغيل حقيقي (level=0)

---

## حل مشاكل حقيقية ظهرت وقت الاختبار على هاردوير

1. **Crash - stack overflow في "Tmr Svc" task** → `CONFIG_FREERTOS_TIMER_TASK_STACK_DEPTH`
   اتزود من 2048 لـ4096 (في المشروعين)
2. **Root اتصل بشبكة WiFi حقيقية تلقائيًا** (SSID/password متخزنين من
   استخدام سابق للشريحة) - ده عكس التصميم (الشبكة لازم تكون معزولة عن
   الإنترنت) → `CONFIG_BRIDGE_EXTERNAL_NETIF_STATION` اتقفلت (في المشروعين)

---

## أداة provisioning (UID + إحداثيات)

`firmware/tools/ips_node_provisioning_tool.html` - صفحة ويب (Edge/Chrome،
Web Serial API) بتولّد Node ID عشوائي، تبعته للجهاز عبر `SET_ID:<hex>`،
وتجمع بيانات كل نود (UID + اسم + X + Y + الدور) في جدول محلي قابل
للتصدير CSV. **مختبرة وشغالة فعليًا.**

**الحالة الحالية:** بترفع CSV بس لسه، **مش متربطة بـSupabase مباشرة**
(الاتصال بقاعدة البيانات كان مقطوع وقت البناء - نرجعلها لما نتأكد من
أعمدة جدول `nodes`).

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

1. **تفعيل BLE/WiFi Coexistence** في `IPS_Mesh_Node` - أولوية حرجة قبل
   أي اختبار ميداني حقيقي (مفيش داعي ليها في Root لأنه مفيهوش BLE)
2. **اختبار Root + Node مع بعض** - تأكيد إن `HEALTH:` lines فعليًا
   بتطلع على Serial monitor بتاع الـRoot بعد ما node يبعت heartbeat
3. **استبدال مفتاح الـAES** بمفتاح حقيقي (مش placeholder) قبل أي نشر
4. **ربط أداة الـprovisioning بـSupabase** - لما تتأكد الأعمدة، نضيف
   رفع مباشر بدل CSV اليدوي
5. Supabase migration لجدول `node_health` (SQL جاهز في MESH_DESIGN.md §7)
6. Dashboard للعرض - مكانه لسه مش محدد
7. اختبار ميداني: hop depth فعلي، RSSI بين نقاط متجاورة، معايرة الـTimeout

## مشاكل/قرارات مفتوحة

- **مكان الـDashboard:** لسه مش متفق عليه
- **أعمدة جدول nodes في Supabase:** الاتصال كان مقطوع، محتاج تأكيد
  قبل ربط أداة الـprovisioning تلقائيًا
- **auto-detect لمنفذ الـSerial في pc_health_service:** حاليًا ثابت في `.env`
