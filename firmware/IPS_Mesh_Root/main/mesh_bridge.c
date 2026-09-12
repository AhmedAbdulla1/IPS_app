#include "mesh_bridge.h"

#include "esp_bridge.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_mesh_lite.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "nvs_flash.h"

#include "health_table.h"

static const char *TAG = "mesh_bridge";

void ips_mesh_bridge_on_heartbeat_received(const uint8_t node_id[IPS_NODE_ID_LEN],
                                            uint8_t hop_count) {
    ips_health_table_update(node_id, hop_count);
}

// بيتنادى من mesh_lite لما raw message بالـmsg_id = IPS_MSG_ID_HEARTBEAT
// يوصل من أي child node. بيفك البيانات لـips_health_heartbeat_t
// (معرّفة في config.h - لازم تتطابق مع الـNode) ويحدّث health_table.
// مفيش response مطلوب (heartbeat فاير-أند-فورجيت)، فبنرجّع out_data=NULL.
static esp_err_t handle_heartbeat_raw_msg(uint8_t *data, uint32_t len,
                                           uint8_t **out_data, uint32_t *out_len,
                                           uint32_t seq) {
    (void)seq;
    if (out_data) *out_data = NULL;
    if (out_len) *out_len = 0;

    if (data == NULL || len < sizeof(ips_health_heartbeat_t)) {
        ESP_LOGW(TAG, "heartbeat raw msg بحجم غلط: %u بايت", (unsigned)len);
        return ESP_ERR_INVALID_SIZE;
    }

    const ips_health_heartbeat_t *hb = (const ips_health_heartbeat_t *)data;
    ips_mesh_bridge_on_heartbeat_received(hb->node_id, hb->hop_count);
    return ESP_OK;
}

static const esp_mesh_lite_raw_msg_action_t s_heartbeat_raw_action = {
    .msg_id      = IPS_MSG_ID_HEARTBEAT,
    .resp_msg_id = 0, // مفيش response - الـheartbeat نفسه بيتكرر دوريًا
    .raw_process = handle_heartbeat_raw_msg,
};

static void wifi_init(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
}

void ips_mesh_bridge_init(void) {
    ESP_LOGI(TAG, "بيهيّئ mesh bridge (Root role)...");

    wifi_init();

    // بيجهّز netif الجسر بين الـmesh والشبكة المحلية - جزء أساسي من
    // esp-mesh-lite (esp-bridge component).
    esp_bridge_create_all_netif();

    esp_mesh_lite_config_t mesh_lite_config = ESP_MESH_LITE_DEFAULT_INIT();

    // ملحوظة: mesh_lite مالوش حقل صريح لـ"الجهاز ده Root، مش child" - الروت
    // بيتحدد بالانتخاب الطبيعي (أول جهاز مبيلاقي راوتر/مفيش mesh تاني
    // بيقرر Root لوحده) - مؤكدين منها فعليًا من لوج التشغيل الحقيقي
    // (level=0). الـjoin_mesh_ignore_router_status المفعّل في menuconfig هو اللي
    // بيضمن إنه يقدر يقرر Root من غير راوتر.

    // esp_mesh_lite_init/start بترجع void في النسخة دي من mesh_lite (تأكدنا منها وقت بناء
    // IPS_Mesh_Node) - من غير ESP_ERROR_CHECK.
    // TODO أمني مهم: مفتاح وهمي لحد الدراسة - لازم يتستبدل قبل أي نشر
    // فعلي (مبنى المبنى، مش مجرد secret في git). لازم يطابق نفس
    // المفتاح في IPS_Mesh_Node/main/mesh_participant.c.
    static const uint8_t s_mesh_aes_key[16] = {
        0x49, 0x50, 0x53, 0x5f, 0x6d, 0x65, 0x73, 0x68,
        0x5f, 0x6c, 0x69, 0x74, 0x65, 0x5f, 0x30, 0x31
    };
    esp_mesh_lite_aes_set_key(s_mesh_aes_key, 128);

    esp_mesh_lite_init(&mesh_lite_config);

    // تسجيل الـcallback اللي بيستقبل heartbeat راو من الـchild nodes - لازم
    // قبل esp_mesh_lite_start() عشان مايفوتش أول heartbeat لو child اتصل بسرعة.
    esp_err_t reg_ret = esp_mesh_lite_raw_msg_action_list_register(&s_heartbeat_raw_action);
    if (reg_ret != ESP_OK) {
        ESP_LOGE(TAG, "فشل تسجيل heartbeat raw msg action: %s", esp_err_to_name(reg_ret));
    }

    esp_mesh_lite_start();

    ESP_LOGI(TAG, "mesh_lite اشتغل. الطبقة الحالية: %d",
             esp_mesh_lite_get_level());
}
