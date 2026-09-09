# Mesh Health Monitoring - Progress Tracking

مرجع تتبع تنفيذ شبكة مراقبة صحة النودز. راجع `MESH_DESIGN.md` للتصميم الكامل.

**قرار الأدوات المعتمد:** ESP-IDF + ESP-MESH-LITE الرسمي (مش painlessMesh، ومش
ESP-MDF/ESP-WIFI-MESH القديم اللي اتوقف). الـNode firmware هيستضيف كود
الـArduino/BLE الحالي كـ"Arduino as ESP-IDF component" جنب mesh_lite component.
الـRoot firmware ESP-IDF نضيف (من غير Arduino، مش محتاج BLE).

**pc_health_service:** Dart CLI (مش Python) عشان يندمج لاحقًا مع تطبيق
الـFlutter Desktop provisioning المخطط له.

---

## هيكل المجلدات

```
firmware/
  IPS_Demo_Node_v2.0.0/     # الفيرموير الحالي (Arduino/.ino) - BLE فقط، بيفضل
                            # كمرجع لحد ما IPS_Mesh_Node يبقى شغال ومُختبر
  IPS_Mesh_Node/            # [جديد - فاضي لسه] ESP-IDF project لكل node فعلي
                            # = BLE advertising (منقول من IPS_Demo_Node_v2.0.0)
                            #   + مشاركة في mesh_lite + heartbeat
  IPS_Mesh_Root/            # [جديد - فاضي لسه] ESP-IDF project لكل Root
                            # = mesh_lite root role + تجميع heartbeats
                            #   + إخراج عبر Serial بروتوكول HEALTH:...
  pc_health_service/        # [جديد - Skeleton كامل] Dart CLI بيقرأ الـSerial
                            # من الـRoot ويرفع batch لـSupabase
  MESH_DESIGN.md            # التصميم المعماري الكامل
  MESH_PROGRESS.md          # الملف ده
  upload-all.ps1            # سكريبت رفع موجود بالفعل (للفيرموير الحالي)
```

---

## حالة المراحل

### Phase 0 - التصميم ✅ خلص
- [x] توثيق الطوبولوجيا الفعلية (Ring + 3 Arms) في `MESH_DESIGN.md`
- [x] التحقق من ESP-MESH-LITE (self-healing / encryption / root-without-router) ✓ مؤكدين من التوثيق الرسمي
- [x] قرار: ESP-IDF + ESP-MESH-LITE (مش Arduino/painlessMesh)
- [x] إنشاء الـfile structure

### Phase 1 - Root Firmware (`IPS_Mesh_Root`) - لسه فاضي
- [ ] مشروع ESP-IDF أساسي (`idf.py create-project`) + إضافة component `espressif/mesh_lite`
- [ ] تفعيل الـRoot كـroot-only (`ESP_MESH_LITE_DEFAULT_INIT` + إعداد بدون router)
- [ ] استقبال heartbeat messages من الـchild nodes (root-level receive API)
- [ ] حفظ جدول حالة in-memory (node_id → last_seen, hop_count)
- [ ] Serial output بروتوكول `HEALTH:<node_id_hex>:<status>:<hop_count>:<last_seen_ms>`
- [ ] تفعيل AES encryption بتاع mesh_lite
- [ ] تفعيل `esp_coex` (احتياطي - الـRoot ممكن يفضل WiFi فقط بدون BLE، نتأكد لو محتاج)

### Phase 2 - Node Firmware (`IPS_Mesh_Node`) - لسه فاضي
- [ ] مشروع ESP-IDF + Arduino كـmanaged component (`idf.py add-dependency "espressif/arduino-esp32"`)
- [ ] نقل كود BLE advertising من `IPS_Demo_Node_v2.0.0.ino` (buildPayload/updateAdvertisement) بأقل تعديل ممكن
- [ ] نقل نظام provisioning (SET_ID/GET_ID عبر Serial + NVS) - **ملاحظة:** لازم نصلّح إن `loadNodeIdFromNvs()` كانت متعلقة (commented) في الكود الأصلي قبل النقل
- [ ] إضافة mesh_lite كـnon-root node
- [ ] تفعيل `esp_coex` (BLE + WiFi mesh على نفس الشريحة - **أولوية حرجة**)
- [ ] Heartbeat task: بناء `HealthHeartbeat` struct وبعتها دوريًا للـparent/root
- [ ] اختبار: هل BLE advertising بيستقر لما mesh traffic يشتغل؟

### Phase 3 - PC Health Service (`pc_health_service`) - Skeleton خلص ✅
- [x] قراءة Serial من الـRoot (`SerialLineReader`)
- [x] Parser لبروتوكول `HEALTH:...` (`HealthUpdate.tryParse`)
- [x] جدول حالة in-memory + حساب dynamic timeout (`NodeHealthTable`)
- [x] Batch upload لـSupabase عبر PostgREST upsert (`SupabaseHealthUploader`)
- [x] wiring كامل في `bin/health_service.dart` (.env → serial → table → upload timer)
- [ ] `dart pub get` + تثبيت نسخة `libserialport` الصحيحة
- [ ] اختبار فعلي مع Root حقيقي
- [ ] retry logic لو الرفع فشل (تراكم بدل فقدان بيانات)
- [ ] (لاحقًا) دمجه مع تطبيق الـFlutter Desktop provisioning المخطط له

### Phase 4 - Supabase - لسه فاضي
- [ ] Migration لجدول `node_health` (SQL جاهز في MESH_DESIGN.md §7، محتاج `apply_migration`)
- [ ] Dashboard بسيط (ONLINE/OFFLINE) - مكانه لسه مش محدد (ويب بسيط؟ جزء من تطبيق الموبايل؟)

### Phase 5 - اختبار ميداني - لسه فاضي
- [ ] قياس hop depth الفعلي في فرع واحد
- [ ] قياس RSSI بين نقاط متجاورة للتأكد من قوة الـoverlap
- [ ] معايرة قيم الـTimeout بناءً على القياسات

---

## مشاكل/قرارات مفتوحة

- **مكان الـDashboard:** لسه مش متفق عليه (تطبيق موبايل/ويب منفصل/جزء من
  تطبيق الـprovisioning).
- **auto-detect لمنفذ الـSerial في pc_health_service:** حاليًا ثابت في
  `.env`، محتاج تحسين لاحقًا.
- **نسخة `libserialport` في `pubspec.yaml`:** مكتوبة تقديريًا (`^0.4.0`)،
  لازم تتأكد بعد أول `dart pub get`.
