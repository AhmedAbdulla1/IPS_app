#pragma once

// إعدادات مشتركة لفيرموير الـRoot. القيم دي نفسها موثقة في
// MESH_DESIGN.md §4.4/§4.5 - خليها متزامنة لو اتغيرت هنا أو في
// pc_health_service/lib/config.dart.

#include <stdint.h>

// سقف طبقات الـmesh (يدعم حتى 15 طبقة)
#define IPS_MESH_MAX_LAYER 15

// كل قد إيه (بالمللي ثانية) الـRoot يطبع الحالة الحالية لكل node معروفة
// على الـSerial، حتى لو مفيش heartbeat جديد وصل (عشان الـPC يفضل عنده
// صورة محدثة، والـtimeout الفعلي بيتحسب PC-side).
#define IPS_HEALTH_REPORT_INTERVAL_MS 2000

// مهلة التوقف ومارسبن القفزات لحساب حالة النود اونلاين/اوفلاين
#define IPS_BASE_TIMEOUT_MS 3000
#define IPS_PER_HOP_MARGIN_MS 800

// طول node_id بالبايت (= esp32_uuid، 16 بايت زي فيرموير الـpositioning).
#define IPS_NODE_ID_LEN 16

// قناة WiFi الثابتة اللي الـmesh الداخلي (SoftAP) بيشتغل عليها - لازم
// تتطابق حرفيًا بين Root وNode، وإلا الأجهزة ممكن متلاقيش بعض حتى
// لو كل حاجة تانية مظبوطة صح (منقول من mesh_lite/examples/no_router الرسمي).
#define IPS_MESH_CHANNEL 11

// --- بروتوكول heartbeat شبكة health monitoring (MESH_DESIGN.md §5) ---
// msg_id للرسائل الخام (raw) اللي بتتبعت من الـnode للـroot. لازم
// يتطابق مع نفس القيمة بالظبط في IPS_Mesh_Node/main/config.h.
#define IPS_MSG_ID_HEARTBEAT 0x1001
#define IPS_MSG_ID_OTA_ANNOUNCE 0x1002

// رقم إصدار فيرموير الـRoot (للتوثيق والمقارنة فقط)
#define IPS_FW_VERSION_MAJOR 1
#define IPS_FW_VERSION_MINOR 0

// --- OTA عبر Serial (PC -> Root) + توزيع عبر mesh (Root -> Nodes) ---
// راجع OTA_PLAN.md للبروتوكول الكامل، وtools/system-monitor/js/ota.js للطرف
// المقابل في المتصفح. القيم دي لازم تتطابق حرفيًا مع الـJS.

// رقم بورت الـUART الموصول فعليًا بالـUSB (نفس البورت اللي الـconsole/printf
// بيخرج عليه افتراضيًا - IDF بيستخدم UART0 كـconsole افتراضي).
#define IPS_OTA_UART_NUM 0

// حجم الـchunk الواحد (بايت) اللي الـPC بيبعتها قبل ما يستنى ACK -
// لازم يطابق OTA_CHUNK_SIZE في tools/system-monitor/js/ota.js بالظبط.
#define IPS_OTA_CHUNK_SIZE 4096

// مهلة الانتظار لأول بايت من الـchunk الجاي بعد ما الـRoot يبعت OTA_READY/
// OTA_PROGRESS - لو الـPC وقف/اتقطع الاتصال، الـRoot يلغي الـOTA ويرجع يطبع health.
#define IPS_OTA_RX_TIMEOUT_MS 15000

// طول أقصى لسطر نصي واحد جاي من الـPC (أوامر زي OTA_START/OTA_END) -
// أي حاجة أطول من كده مش مفروض تحصل في البروتوكول ده.
#define IPS_SERIAL_LINE_MAX_LEN 160

// مفتاح NVS لتخزين "فيه فيرموير لسه محتاج يتوزّع للـNodes" - بيتحط قبل
// الـreboot في ota_receiver.c ويتقرا بعد الـreboot في ota_relay.c.
#define IPS_OTA_NVS_NAMESPACE "ips_ota"
#define IPS_OTA_NVS_KEY_PENDING "relay_pending"
#define IPS_OTA_NVS_KEY_SIZE "relay_size"
#define IPS_OTA_NVS_KEY_VERSION "relay_ver"

#pragma pack(push, 1)
typedef struct {
    uint8_t  node_id[IPS_NODE_ID_LEN]; // = g_nodeId (esp32_uuid) بتاعت الـchild
    uint16_t seq;                       // عداد متزايد محلي لاكتشاف الفقد
    uint8_t  hop_count;                 // كام قفزة وصلت بيها للـroot
    uint8_t  fw_major;                  // إصدار فيرموير الـNode
    uint8_t  fw_minor;                  // إصدار فيرموير الـNode (minor)
    uint32_t uptime_ms;                 // وقت تشغيل الـnode
} ips_health_heartbeat_t;

typedef struct {
    uint32_t size;                      // الحجم بالبايت
    uint8_t  fw_major;                  // الإصدار المعلن (major)
    uint8_t  fw_minor;                  // الإصدار المعلن (minor)
    char     version[16];               // نص الإصدار مثل "1.4"
} ips_ota_announce_t;
#pragma pack(pop)

