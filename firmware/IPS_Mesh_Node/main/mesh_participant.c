#include "mesh_participant.h"

#include <string.h>

#include "esp_bridge.h"
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

// منقول من مثال mesh_lite/examples/no_router الرسمي - بيضبط STA (الاسكان
// اللي الـnode بيستخدمه للـscan وللبحث عن Root) وAP (نفس SSID/Password/Channel
// بتاع الـmesh الداخلي لو الـnode اتحوّل Root يوم ما - احتياطي).
static void configure_wifi_interfaces(void) {
    wifi_config_t sta_cfg;
    memset(&sta_cfg, 0, sizeof(sta_cfg));
    esp_bridge_wifi_set_config(WIFI_IF_STA, &sta_cfg);

    wifi_config_t ap_cfg = {
        .ap = {
            .ssid = CONFIG_BRIDGE_SOFTAP_SSID,
            .password = CONFIG_BRIDGE_SOFTAP_PASSWORD,
            .channel = IPS_MESH_CHANNEL,
        },
    };
    esp_bridge_wifi_set_config(WIFI_IF_AP, &ap_cfg);
}

// منقول من نفس المثال الرسمي - بيضبط SSID/Password الداخليين اللي
// الـmesh بتستخدمهم عشان الأجهزة تتصل ببعض (مش أي شبكة خارجية).
// بيدوّر الأول في NVS (لو كان متسجل قبل كده)، ولو مش لاقي بيرجع للقيم
// الافتراضية من menuconfig (CONFIG_BRIDGE_SOFTAP_SSID/PASSWORD).
static void app_wifi_set_softap_info(void) {
    char softap_ssid[33] = {0};
    char softap_psw[64] = {0};
    size_t ssid_size = sizeof(softap_ssid);
    size_t psw_size = sizeof(softap_psw);

    if (esp_mesh_lite_get_softap_ssid_from_nvs(softap_ssid, &ssid_size) != ESP_OK) {
        snprintf(softap_ssid, sizeof(softap_ssid), "%.32s", CONFIG_BRIDGE_SOFTAP_SSID);
    }
    if (esp_mesh_lite_get_softap_psw_from_nvs(softap_psw, &psw_size) != ESP_OK) {
        strlcpy(softap_psw, CONFIG_BRIDGE_SOFTAP_PASSWORD, sizeof(softap_psw));
    }

    esp_mesh_lite_set_softap_info(softap_ssid, softap_psw);
}

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

    // !!!حرج!!!  esp_bridge_create_all_netif() لازم تبني STA netif
    // (CONFIG_BRIDGE_EXTERNAL_NETIF_STATION=y في sdkconfig) بجانب SoftAP.
    // من غير STA، الـwifi بيشتغل AP-only ومش بيقدر يعمل scan →
    // esp_mesh_lite_wifi_scan_start بترجع ESP_FAIL ولا بيلاقي الـRoot أبدًا.
    // ده مش معناه هيتصل بالنت - ده بس بيخلّي driver الـWiFi في وضع APSTA.
    esp_bridge_create_all_netif();

    // إضافة حرجة (راجع MESH_PROGRESS.md 2026-09-13): من غيرها الأجهزة
    // مش بتتفق على إعدادات WiFi الداخلية بتاعة الـmesh بشكل كامل.
    configure_wifi_interfaces();

    esp_mesh_lite_config_t mesh_lite_config = ESP_MESH_LITE_DEFAULT_INIT();

    // بنفرض القيم دي صراحة في الكود (مش بس نعتمد على menuconfig) - نفس
    // اللي عامله مثال mesh_lite/examples/no_router الرسمي بالظبط.
    mesh_lite_config.join_mesh_ignore_router_status = true;
    // الـNode تحديدًا: true هنا (عكس Root) - الـNode بيحاول ينضم لـmesh
    // حتى من غير راوتر WiFi متكوّن.
    mesh_lite_config.join_mesh_without_configured_wifi = true;

    // TODO امني مهم: مفتاح وهمي لحد الدراسة - لازم يتستبدل قبل أي نشر
    // فعلي. لازم يطابق نفس المفتاح في IPS_Mesh_Root/main/mesh_bridge.c.
    static const uint8_t s_mesh_aes_key[16] = {
        0x49, 0x50, 0x53, 0x5f, 0x6d, 0x65, 0x73, 0x68,
        0x5f, 0x6c, 0x69, 0x74, 0x65, 0x5f, 0x30, 0x31
    };
    esp_mesh_lite_aes_set_key(s_mesh_aes_key, 128);

    esp_mesh_lite_init(&mesh_lite_config);

    // منقول من المثال الرسمي - لازم يتنادى بعد init وقبل start.
    app_wifi_set_softap_info();

    // منقول من المثال الرسمي - تحديد صريح إن الـNode ممنوع يبقى level 1
    // (Root). راجع MESH_PROGRESS.md 2026-09-13 للتفاصيل.
    esp_mesh_lite_set_disallowed_level(1);

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
