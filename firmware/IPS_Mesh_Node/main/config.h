#pragma once

// إعدادات مشتركة لفيرموير الـNode - ESP-IDF native (NimBLE + mesh_lite،
// من غير Arduino). زامن أي تعديل هنا مع ../MESH_DESIGN.md
// وpc_health_service/lib/config.dart لو القيم اتغيرت.

#include <stdint.h>

// طول node_id بالبايت = esp32_uuid (زي فيرموير الـpositioning الأصلي).
#define IPS_NODE_ID_LEN 16

// قناة WiFi الثابتة اللي الـmesh الداخلي (SoftAP) بيشتغل عليها - لازم
// تتطابق حرفيًا مع نفس القيمة في IPS_Mesh_Root/main/config.h، وإلا الأجهزة
// ممكن متلاقيش بعض حتى لو كل حاجة تانية مظبوطة صح.
#define IPS_MESH_CHANNEL 11

// كل قد إيه (بالمللي ثانية) الـnode يبعت heartbeat لأقرب parent/root.
#define IPS_HEARTBEAT_INTERVAL_MS 2000

// سقف طبقات الـmesh (يدعم حتى 15 طبقة للـMulti-Root والـFailover الأفقي الطويل)
#define IPS_MESH_MAX_LAYER 15

// رقم الـ GPIO المتصل بالليد للمؤشرات الضوئية (النبض ونقل الفيرموير)
#define IPS_LED_GPIO 2

// --- BLE advertising (نفس قيم IPS_Demo_Node_v2.0.0.ino الأصلية) ---

// Must match BleConstants.manufacturerCompanyId في تطبيق الـFlutter.
#define IPS_BLE_COMPANY_ID 0xFFFF

#define IPS_NODE_X_CM 1000
#define IPS_NODE_Y_CM 600
#define IPS_NODE_FLOOR 0

#define IPS_FW_VERSION_MAJOR 1
#define IPS_FW_VERSION_MINOR 6

// وحدة الإعلان = 0.625ms - نفس القيمة الأصلية (244 وحدة \u2248 152.5ms).
#define IPS_ADV_INTERVAL_UNITS 244

// --- بروتوكول heartbeat شبكة health monitoring (MESH_DESIGN.md §5) ---
// msg_id للرسائل الخام (raw) اللي بتتبعت من الـnode للـroot عبر
// esp_mesh_lite_send_msg(ESP_MESH_LITE_RAW_MSG, ...). لازم يتطابق مع
// نفس القيمة بالظبط في IPS_Mesh_Root/main/config.h.
#define IPS_MSG_ID_HEARTBEAT 0x1001
#define IPS_MSG_ID_OTA_ANNOUNCE 0x1002

#pragma pack(push, 1)
typedef struct {
    uint8_t  node_id[IPS_NODE_ID_LEN]; // = g_nodeId (esp32_uuid)
    uint16_t seq;                       // عداد متزايد محلي لاكتشاف الفقد
    uint8_t  hop_count;                 // = esp_mesh_lite_get_level() وقت الإرسال
    uint8_t  fw_major;                  // = IPS_FW_VERSION_MAJOR
    uint8_t  fw_minor;                  // = IPS_FW_VERSION_MINOR
    uint32_t uptime_ms;                 // esp_timer_get_time() / 1000
} ips_health_heartbeat_t;

typedef struct {
    uint32_t size;                      // الحجم بالبايت
    uint8_t  fw_major;                  // الإصدار المعلن (major)
    uint8_t  fw_minor;                  // الإصدار المعلن (minor)
    char     version[16];               // نص الإصدار مثل "1.4"
} ips_ota_announce_t;
#pragma pack(pop)
