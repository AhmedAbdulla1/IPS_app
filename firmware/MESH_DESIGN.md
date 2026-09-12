# تصميم شبكة مراقبة صحة النودز (Node Health Monitoring Network)

**الحالة:** تصميم معتمد - قيد التنفيذ
**آخر تحديث:** 2026-09-10
**يخص:** مبنى مجلس النواب - الدور الواحد (المرحلة الأولى)

---

## 1. المشكلة

كل Node (ESP32) في نظام الـIPS مغذاة كهربيًا بشكل مستقل، ومفيش توصيل سلكي
بين الـNodes. محتاجين نعرف تلقائيًا لو node وقعت/فصلت من غير ما حد يلف
على المبنى يفحصها فيزيائيًا.

BLE مش مناسب لده لوحده، لأن دوره الأساسي حاليًا هو بث BLE Advertisements
للموبايلات (positioning). فمحتاجين قناة منفصلة تمامًا لمراقبة الصحة.

---

## 2. الفصل بين الشبكتين

```
Positioning Network                    Health Monitoring Network
──────────────────                    ──────────────────────────
BLE Advertisements (NimBLE)            ESP-WIFI-MESH (mesh_lite)
        │                                      │
    Smartphone                            Root Node(s)
        │                                      │
   Position Engine                    PC محلي (غرفة التحكم)
                                               │
                                          Supabase
```

القناتين لازم يفضلوا منفصلين تمامًا في الكود والبروتوكول. التقاطع
الوحيد بينهم: **شريحة الراديو الفيزيائية نفسها** (BLE + WiFi على نفس
الـRF front-end في ESP32) - وده بيتطلب تفعيل الـcoexistence من أول
التصميم، مش إضافته لاحقًا. لازم يتفحص عمليًا: هل BLE advertising
بيتأثر لما حركة الـmesh تزيد؟

---

## 3. الطوبولوجيا الفعلية للمبنى (مش Mesh كثيف)

بعد فحص المخطط الفعلي، الطوبولوجيا مش mesh كثيف عشوائي، هي بنية محددة:

```
                    ┌─────────────────┐
                    │   Ring (ممر     │
                    │  دائري حوالين   │
        ┌───────────┤  القاعة الكبيرة)├───────────┐
        │           └────────┬────────┘           │
        │                    │                     │
    Arm 1 (~20)          Arm 2 (~20)           Arm 3 (~20)
    (جناح/فرع)            (جناح/فرع)            (جناح/فرع)
    سلسلة خطية            سلسلة خطية             سلسلة خطية
    بتراكب مدى             بتراكب مدى              بتراكب مدى
```

**خصائص كل جزء:**

| الجزء | الطوبولوجيا | مستوى الـResilience |
|---|---|---|
| الـRing (حوالين القاعة) | حلقة مقفولة | **عالي** - مسارين لأي نقطة عليها |
| كل Arm (جناح، ~20 نقطة) | سلسلة خطية بتراكب مدى | **متوسط** - إعادة اتصال ممكنة عبر orphan re-parenting لو فيه تراكب مدى كافي، مش مضمونة 100% |

كل node بتشوف 2-3 جيران بس (مش الشبكة كلها)، والمسافات بين نقاط كل
فرع قريبة بما يكفي إن نطاقات الإرسال بتـoverlap - يعني لو node وقعت،
اللي بعدها في السلسلة يقدر يحاول يتصل بنود تالتة أبعد شوية بدل ما
يفصل تمامًا.

---

## 4. القرارات المعمارية

### 4.1 استخدام ESP-WIFI-MESH (mesh_lite) بدل بروتوكول مخصص
مكوّن جاهز في ESP-IDF (ESP-MESH-LITE، الوريث لـESP-MDF المتوقف)، بيوفر
Node Discovery, Routing, Forwarding, ACK/Retry, TTL, و**Self-Healing
عبر Orphan Re-parenting** بشكل مُختبر وجاهز. متعملش إعادة اختراع لعجلة
الـmesh stack.

### 4.1.1 [محدّث] الفيرموير كله ESP-IDF native - مفيش Arduino
**القرار الأصلي كان "Arduino as an ESP-IDF component"** عشان نحافظ على
كود الـBLE الموجود (`IPS_Demo_Node_v2.0.0.ino`) من غير إعادة كتابته.
اتغيّر القرار بعد ما واجهنا مشكلة توافق حقيقية: `arduino-esp32` لسه مش
بيدعم ESP-IDF v6.x رسميًا (النسخة المتوافقة لسه alpha وموثّقة رسميًا
إنها ناقصة مكونات).

بما إن كود الـBLE advertising بسيط (non-connectable advertisement،
مفيش GATT services ولا اتصالات)، اتقرر **إعادة كتابته مباشرة بـNimBLE**
(المكوّن `bt` المدمج في ESP-IDF نفسه، مش تبعية خارجية). الفايدة:
- مفيش مشكلة توافق نسخ بين framework وتاني (كله ESP-IDF نضيف)
- مفيش overhead طبقة توافق Arduino فوق ESP-IDF
- الكود الأصلي محفوظ كمرجع في `IPS_Mesh_Node/main/_legacy_arduino_attempt/`

### 4.2 مكان الـRoot: على الـRing
الـRoot لازم يتحط على الممر الدائري (الـRing) نفسه، مش في نقطة عشوائية
ولا داخل فرع معين، عشان:
- يستفيد من الـredundancy بتاعة الحلقة (مسارين لو جار وقع)
- يبقى قريب من مداخل كل الأفرع التلاتة بالتساوي تقريبًا

### 4.3 هوية الـNode: نفس esp32_uuid الموجود
مفيش نظام IDs منفصل. نفس الـesp32_uuid المستخدم في provisioning
(SET_ID/GET_ID) هو نفسه node_id في شبكة الـhealth. ده بيربط مباشرة
بجدول `nodes` في Supabase من غير أي تعارض.

### 4.4 سقف الـLayers
`CONFIG_MESH_MAX_LAYER` يتحدد بـ **8-10** (مش الافتراضي 25) - عشان
الأفرع الطويلة (~20 node) ممكن توصل لعمق قفزات كبير نسبيًا حتى مع
الـoverlap.

### 4.5 Timeout ديناميكي حسب عدد القفزات
```
node_timeout_ms = BASE_TIMEOUT_MS + (hop_count × PER_HOP_MARGIN_MS)
```
قيم مبدئية مقترحة (تتظبط بعد اختبار فعلي):
- `BASE_TIMEOUT_MS = 3000`
- `PER_HOP_MARGIN_MS = 800`

### 4.6 التشفير
AES encryption المدمج في ESP-MESH-LITE لازم يتفعّل من أول يوم (مبنى
حساس أمنيًا).

### 4.7 اتصال الـRoot بالخارج: عبر PC محلي، مش WiFi مباشر
الـRoot **معزول تمامًا عن الإنترنت**. بيتوصل بـPC في غرفة التحكم عبر
Serial/USB بس. الـPC هو المسؤول الوحيد عن الرفع لـSupabase.

**الأسباب:**
- أمان: مفيش جهاز IoT رخيص متصل مباشرة بالإنترنت في مبنى حساس
- تبسيط الراديو: الـRoot مشغول أصلاً بإدارة شجرة الـmesh
- موثوقية: انقطاع الإنترنت مش بيأثر على تجميع بيانات الـhealth نفسها

```
ESP32 Nodes (Mesh, per Arm)
      │ heartbeat عبر الـmesh
      ▼
  Root Node (على الـRing) ── Serial/USB ──▶ PC محلي (غرفة التحكم)
                                                 │
                                          جدول حالة in-memory
                                                 │
                                          رفع دوري batch
                                                 ▼
                                             Supabase
```

---

## 5. بروتوكول الـHeartbeat (تطبيقي - App Layer فوق الـMesh)

```c
struct HealthHeartbeat {
  uint8_t  node_id[16];    // = esp32_uuid
  uint16_t seq;            // رقم متسلسل لاكتشاف الفقد
  uint8_t  hop_count;      // كام قفزة وصلت بيها للـRoot
  uint8_t  reserved;       // مكان لبيانات مستقبلية (battery لو بطارية)
  uint32_t uptime_ms;      // وقت تشغيل النود
};
```

## 6. بروتوكول الـSerial (Root → PC)

```
HEALTH:<node_id_hex>:<status>:<hop_count>:<last_seen_ms>
```

سطر واحد لكل تحديث حالة. الـPC بيبارس السطر ويحدث جدوله الداخلي،
وبيرفع batch لـSupabase كل فترة زمنية (مش على كل رسالة).

## 7. جدول Supabase مقترح

```sql
create table node_health (
  node_esp32_uuid text primary key references nodes(esp32_uuid),
  status text not null check (status in ('online', 'offline')),
  hop_count smallint,
  last_seen_at timestamptz not null,
  updated_at timestamptz default now()
);
```

**ملاحظة مهمة للداشبورد:** "Offline" معناها "مفيش بيانات وصلت من النود
دي للـRoot"، مش بالضرورة "النود نفسها معطوبة".

---

## 8. المخاطر المفتوحة (لسه محتاجة اختبار فعلي)

1. **تأثير BLE/WiFi coexistence على استقرار advertising** - لازم
   يتفحص على node حقيقي، مش نظريًا بس.
2. **قيم الـTimeout مبدئية** - محتاجة معايرة بعد قياس الـhop depth الفعلي.
3. **مدى فعالية الـoverlap في كل فرع** - محتاج قياس RSSI فعلي.
4. **API إرسال/استقبال raw data في mesh_lite** - مش موثّق بالتفصيل
   الكافي في المصادر المتاحة، محتاج تأكيد من الـheader بعد أول build
   (راجع MESH_PROGRESS.md).
5. **NimBLE على ESP-IDF v6.1** - أسماء دوال init ممكن تكون اتغيّرت
   شوية بين النسخ (راجع TODO في `ble_node.c`).

---

## 9. خطوات التنفيذ

راجع `MESH_PROGRESS.md` للحالة اللحظية والـfile structure الفعلي.
