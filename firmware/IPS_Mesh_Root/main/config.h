#pragma once

// إعدادات مشتركة لفيرموير الـRoot. القيم دي نفسها موثقة في
// MESH_DESIGN.md §4.4/§4.5 - خليها متزامنة لو اتغيرت هنا أو في
// pc_health_service/lib/config.dart.

#include <stdint.h>

// سقف طبقات الـmesh (بيتظبط فعليًا من menuconfig كمان - القيمة هنا
// للاستخدام في أي حسابات جوه كود الـapp نفسه لو احتجنا).
#define IPS_MESH_MAX_LAYER 10

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

// رقم إصدار فيرموير الـRoot (للتوثيق والمقارنة فقط)
#define IPS_FW_VERSION_MAJOR 1
#define IPS_FW_VERSION_MINOR 0

#pragma pack(push, 1)
typedef struct {
    uint8_t  node_id[IPS_NODE_ID_LEN]; // = g_nodeId (esp32_uuid) بتاعت الـchild
    uint16_t seq;                       // عداد متزايد محلي لاكتشاف الفقد
    uint8_t  hop_count;                 // كام قفزة وصلت بيها للـroot
    uint8_t  fw_major;                  // إصدار فيرموير الـNode
    uint8_t  fw_minor;                  // إصدار فيرموير الـNode (minor)
    uint32_t uptime_ms;                 // وقت تشغيل الـnode
} ips_health_heartbeat_t;
#pragma pack(pop)

