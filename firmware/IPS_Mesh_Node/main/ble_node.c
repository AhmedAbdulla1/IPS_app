#include "ble_node.h"

#include <string.h>

#include "esp_log.h"
#include "esp_nimble_hci.h"
#include "host/ble_hs.h"
#include "host/util/util.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"

#include "config.h"
#include "node_id_store.h"

static const char *TAG = "ble_node";

static uint8_t s_own_addr_type;

static uint8_t read_battery_percent(void) {
    return 85;  // placeholder - mains-powered demo board (زي الأصلي).
}

static void build_payload(uint8_t *out_payload /* >= 24 bytes */) {
    size_t offset = 0;
    memcpy(out_payload + offset, g_nodeId, IPS_NODE_ID_LEN);
    offset += IPS_NODE_ID_LEN;

    out_payload[offset++] = (uint8_t)(IPS_NODE_X_CM & 0xFF);
    out_payload[offset++] = (uint8_t)((IPS_NODE_X_CM >> 8) & 0xFF);
    out_payload[offset++] = (uint8_t)(IPS_NODE_Y_CM & 0xFF);
    out_payload[offset++] = (uint8_t)((IPS_NODE_Y_CM >> 8) & 0xFF);
    out_payload[offset++] = IPS_NODE_FLOOR;
    out_payload[offset++] = read_battery_percent();
    out_payload[offset++] = IPS_FW_VERSION_MAJOR;
    out_payload[offset++] = IPS_FW_VERSION_MINOR;
}

// callback الأحداث بتاع GAP - مش محتاجين نعمل حاجة فيه فعليًا لأن
// الإعلان non-connectable (زي الأصلي: ADV_TYPE_NONCONN_IND)، بس NimBLE
// محتاج الـcallback يتسجل.
static int ble_gap_event_cb(struct ble_gap_event *event, void *arg) {
    (void)event;
    (void)arg;
    return 0;
}

static void start_advertising(void) {
    uint8_t payload[24];
    build_payload(payload);

    uint8_t full_data[2 + sizeof(payload)];
    full_data[0] = (uint8_t)(IPS_BLE_COMPANY_ID & 0xFF);
    full_data[1] = (uint8_t)((IPS_BLE_COMPANY_ID >> 8) & 0xFF);
    memcpy(full_data + 2, payload, sizeof(payload));

    struct ble_hs_adv_fields fields;
    memset(&fields, 0, sizeof(fields));
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.mfg_data = full_data;
    fields.mfg_data_len = sizeof(full_data);

    int rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "ble_gap_adv_set_fields فشلت: rc=%d", rc);
        return;
    }

    struct ble_gap_adv_params adv_params;
    memset(&adv_params, 0, sizeof(adv_params));
    adv_params.conn_mode = BLE_GAP_CONN_MODE_NON;
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;
    adv_params.itvl_min = IPS_ADV_INTERVAL_UNITS;
    adv_params.itvl_max = IPS_ADV_INTERVAL_UNITS;

    rc = ble_gap_adv_start(s_own_addr_type, NULL, BLE_HS_FOREVER, &adv_params,
                            ble_gap_event_cb, NULL);
    if (rc != 0) {
        ESP_LOGE(TAG, "ble_gap_adv_start فشلت: rc=%d", rc);
        return;
    }

    ESP_LOGI(TAG, "✅ BLE Advertising active! Company ID: 0x%04X, Payload: 24 bytes, Interval: %d units",
             IPS_BLE_COMPANY_ID, IPS_ADV_INTERVAL_UNITS);
}

void ble_node_refresh_advertisement(void) {
    ble_gap_adv_stop();  // بيتجاهل الخطأ لو أصلاً مش شغال إعلان.
    start_advertising();
}

// بينادى لما NimBLE host يخلص sync مع الـcontroller - أول فرصة آمنة
// نبدأ فيها الإعلان.
static void ble_app_on_sync(void) {
    int rc;

    // تأكد من وجود عنوان MAC محدد للـ BLE host
    rc = ble_hs_util_ensure_addr(0);
    if (rc != 0) {
        ESP_LOGE(TAG, "ble_hs_util_ensure_addr فشلت: rc=%d", rc);
        return;
    }

    rc = ble_hs_id_infer_auto(0, &s_own_addr_type);
    if (rc != 0) {
        ESP_LOGE(TAG, "ble_hs_id_infer_auto فشلت: rc=%d", rc);
        return;
    }

    uint8_t addr[6] = {0};
    ble_hs_id_copy_addr(s_own_addr_type, addr, NULL);
    ESP_LOGI(TAG, "BLE MAC Address: %02x:%02x:%02x:%02x:%02x:%02x (type=%d)",
             addr[5], addr[4], addr[3], addr[2], addr[1], addr[0], s_own_addr_type);

    start_advertising();
}

static void ble_host_task(void *param) {
    (void)param;
    nimble_port_run();  // بيفضل شغال لحد ما nimble_port_stop() تتنادى.
    nimble_port_freertos_deinit();
}

void ble_node_start(void) {
    // TODO: تأكد من الاسم الصحيح لدالة init الخاصة بـHCI/controller في
    // نسخة ESP-IDF v6.1 المثبتة - esp_nimble_hci_init() كانت الشائعة في
    // نسخ سابقة، بعض الإصدارات الأحدث بتدمجها جوه nimble_port_init()
    // نفسها. لو الـbuild فشل هنا، دي أول نقطة تتأكد منها.
    nimble_port_init();

    ble_hs_cfg.sync_cb = ble_app_on_sync;

    nimble_port_freertos_init(ble_host_task);

    ESP_LOGI(TAG, "NimBLE host بدأ - في انتظار sync مع الـcontroller...");
}
