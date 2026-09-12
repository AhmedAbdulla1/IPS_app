#include "mesh_participant.h"

#include <string.h>

#include "esp_event.h"
#include "esp_log.h"
#include "esp_mesh_lite.h"
#include "esp_netif.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "nvs_flash.h"

#include "config.h"
#include "node_id_store.h"

static const char *TAG = "mesh_participant";

void mesh_participant_setup(void) {
    ESP_LOGI(TAG, "بيهيّئ mesh_lite (non-root)...");

    // NVS اتعملها init بالفعل في app_main قبل node_id_store_init() -
    // نادي هنا تاني وتجاهل ESP_ERR_INVALID_STATE لو حصل.
    esp_err_t nvs_ret = nvs_flash_init();
    if (nvs_ret != ESP_OK && nvs_ret != ESP_ERR_INVALID_STATE) {
        ESP_ERROR_CHECK(nvs_ret);
    }

    esp_err_t netif_ret = esp_netif_init();
    if (netif_ret != ESP_OK && netif_ret != ESP_ERR_INVALID_STATE) {
        ESP_ERROR_CHECK(netif_ret);
    }

    esp_err_t evt_ret = esp_event_loop_create_default();
    if (evt_ret != ESP_OK && evt_ret != ESP_ERR_INVALID_STATE) {
        ESP_ERROR_CHECK(evt_ret);
    }

    wifi_init_config_t wifi_cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_err_t wifi_ret = esp_wifi_init(&wifi_cfg);
    if (wifi_ret != ESP_OK && wifi_ret != ESP_ERR_INVALID_STATE) {
        ESP_ERROR_CHECK(wifi_ret);
    }

    esp_mesh_lite_config_t mesh_lite_config = ESP_MESH_LITE_DEFAULT_INIT();

    // TODO امني مهم: مفتاح وهمي لحد الدراسة - لازم يتستبدل قبل أي نشر
    // فعلي. لازم يطابق نفس المفتاح في IPS_Mesh_Root/main/mesh_bridge.c.
    static const uint8_t s_mesh_aes_key[16] = {
        0x49, 0x50, 0x53, 0x5f, 0x6d, 0x65, 0x73, 0x68,
        0x5f, 0x6c, 0x69, 0x74, 0x65, 0x5f, 0x30, 0x31
    };
    esp_mesh_lite_aes_set_key(s_mesh_aes_key, 128);

    // ملحوظة: mesh_lite مالوش حقل صريح في esp_mesh_lite_config_t لـ"النود دي Root" -
    // الروت بيتحدد بالانتخاب الطبيعي (أول node مبيلاقي راوتر/مفيش mesh تاني، بيقرر
    // Root لوحده) - مؤكدين منها فعليًا من لوج التشغيل الحقيقي (level=0).

    // esp_mesh_lite_init/start بترجع void في النسخة دي من mesh_lite
    // (مش esp_err_t زي ما افترضنا الأول) - من غير ESP_ERROR_CHECK.
    esp_mesh_lite_init(&mesh_lite_config);
    esp_mesh_lite_start();

    ESP_LOGI(TAG, "mesh_lite اشتغل (node). الطبقة الحالية: %d",
             esp_mesh_lite_get_level());
}

void mesh_participant_send_heartbeat(void) {
    static uint16_t s_seq = 0;

    ips_health_heartbeat_t hb = {0};
    memcpy(hb.node_id, g_nodeId, IPS_NODE_ID_LEN);
    hb.seq        = s_seq++;
    hb.hop_count  = esp_mesh_lite_get_level();
    hb.reserved   = 0;
    hb.uptime_ms  = (uint32_t)(esp_timer_get_time() / 1000);

    esp_mesh_lite_msg_config_t conf = {0};
    conf.raw_msg.msg_id            = IPS_MSG_ID_HEARTBEAT;
    conf.raw_msg.expect_resp_msg_id = 0; // fire-and-forget - مفيش response متوقع
    conf.raw_msg.max_retry          = 1; // محاولة واحدة بس - الـheartbeat نفسه بيتكرر كل IPS_HEARTBEAT_INTERVAL_MS
    conf.raw_msg.retry_interval     = 100;
    conf.raw_msg.data               = (const uint8_t *)&hb;
    conf.raw_msg.size               = sizeof(hb);
    conf.raw_msg.raw_resend          = esp_mesh_lite_send_raw_msg_to_root;
    conf.raw_msg.raw_send_fail       = NULL;

    esp_err_t err = esp_mesh_lite_send_msg(ESP_MESH_LITE_RAW_MSG, &conf);
    if (err != ESP_OK) {
        ESP_LOGD(TAG, "heartbeat send fail (seq=%u): %s", hb.seq, esp_err_to_name(err));
    }
}
