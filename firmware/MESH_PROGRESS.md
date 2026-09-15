# Mesh Health Monitoring - Progress Tracking

مرجع تتبع تنفيذ شبكة مراقبة صحة النودز. راجع `MESH_DESIGN.md` للتصميم الكامل.

**قرار الأدوات المعتمد:** ESP-IDF + ESP-MESH-LITE الرسمي. الفيرموير كله (Root وNode) ESP-IDF native.

---

## 🟢 إنجازات حاسمة وتحديثات المعمارية (2026-09-14)

### 1. اعتماد أداة Web Serial Health Monitor والواجهة
- **القرار:** تم الاستغناء تماماً عن تطبيق Dart CLI لصالح أداة الويب المباشرة عبر **Web Serial API**:
  `firmware/tools/ips_mesh_health_monitor.html`
- **السبب:** الاتصال المباشر عبر المتصفح (Edge / Chrome) بكابل USB Serial أسهل وأكثر استقراراً، وبدون أي تعقيدات في تعريفات الـ Sockets أو ملفات `.dll`.

### 2. مخرجات JSON نظيفة من ESP32 Root
- تم تعديل فيرموير `IPS_Mesh_Root/main/serial_output.c` لطباعة بيانات الصحة بصيغة JSON واضحة ومباشرة عبر Serial:
  `{"type":"health","node_id":"...","status":"online","hop_count":2,"last_seen_ms":...}`

### 3. إصلاح Deadlock Mutex في السيرفر
- تم حل مشكلة توقف استجابة TCP Server في `serial_output.c` بنقل `accept()` خارج قفل الـ Mutex.

### 4. تنظيف النودز المنتهية وحساب المهلة الديناميكية (Dynamic Timeout)
- إضافة دالة `ips_health_table_purge_expired()` لمسح النودز المقطوعة تلقائياً بعد 12 ثانية من عدم الاستجابة.
- حساب مهلة التوقف الديناميكية حسب رقم الطبقة (Hop Count):
  `Timeout = 3000ms + (HopCount * 800ms)`
- عرض النود المقطوعة فورياً بوضع **`Offline` (مقطوع)** باللون الأحمر على واجهة الويب بمجرد انقطاع إشارات الـ Heartbeats.

---

## 🔴 حل مشاكل حقيقية ظهرت وقت الاختبار (بالترتيب الزمني)

1. **Arduino مش متوافق مع ESP-IDF v6.x** → تحول كامل لـNimBLE (ESP-IDF native)
2. **`json`/`wifi_provisioning` مش موجودين في v6.x** → النزول لـv5.5.5
3. **`espressif__iot_bridge` محتاج `esp_driver_gpio`** → إضافته لـ`requires`
   في CMakeLists.txt بتاع المكوّن
4. **إعدادات mesh_lite (Vendor ID, Mesh ID, Max Level) undeclared** → تفعيل
   عبر `idf.py menuconfig`
5. **`esp_mesh_lite_init/start` بترجع `void` مش `esp_err_t`** → شلنا
   `ESP_ERROR_CHECK` من حواليهم
6. **Partition table 1MB مش كافي** → `partitions.csv` مخصص بـ2MB
7. **Crash - stack overflow في "Tmr Svc"** → `CONFIG_FREERTOS_TIMER_TASK_STACK_DEPTH=4096`
8. **Root اتصل بشبكة WiFi حقيقية تلقائيًا** → `CONFIG_BRIDGE_EXTERNAL_NETIF_STATION` اتقفلت
9. **`esp_bridge.h: No such file`** → `PRIV_REQUIRES espressif__iot_bridge`
10. **Node وRoot ما بيلاقوش بعض** → تم تحديد `set_allowed_level(1)` للـRoot و `set_disallowed_level(1)` للـNode.
11. **توقف استجابة الـ TCP وتأخير البيانات** → تم إصلاح قفل الـ Mutex في `serial_output.c`.
12. **استمرار عرض النود المقطوعة كـ Online** → قمنا بإضافة Purging للنودز المنتهية وحساب الـ Dynamic Timeout على الـ Root وواجهة الويب.

---

## 📁 هيكل المجلدات المعتمد

```
firmware/
  IPS_Demo_Node_v2.0.0/     # الفيرموير القديم (Arduino) - مرجع بس
  IPS_Mesh_Node/            # ESP-IDF native (NimBLE + mesh_lite)
  IPS_Mesh_Root/            # ESP-IDF نضيف (mesh_lite root)
  tools/
    ips_node_provisioning_tool.html   # ✅ أداة التجهيز (Web Serial + Supabase)
    ips_mesh_health_monitor.html      # ✅ أداة مراقبة الشبكة المباشرة (Web Serial)
  MESH_DESIGN.md
  MESH_PROGRESS.md
  upload-all.ps1
```

---

## 🎯 أولويات التنفيذ الجاية

1. **اختبار التوصيل عبر قفزات متعددة (Multi-hop Routing):**
   تجربة وضع نود بعيدة عن الـ Root وتوصيلها عبر نود أخت وسيطة (Hop 2 / Hop 3) وتأكيد وصول البيانات وتقرير الـ Hop Count بدون مشاكل.
2. استبدال مفتاح الـAES بمفتاح حقيقي قبل أي نشر ميداني.
3. اختبار ميداني لمعايرة قياسات الـ Timeout تحت ضغط التغطية.
