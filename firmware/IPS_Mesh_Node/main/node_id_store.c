#include "node_id_store.h"

#include <string.h>
#include "esp_log.h"
#include "nvs.h"
#include "nvs_flash.h"

static const char *TAG = "node_id_store";
static const char *NVS_NAMESPACE = "ips";
static const char *NVS_KEY_NODE_ID = "node_id";

uint8_t g_nodeId[IPS_NODE_ID_LEN];

static void log_node_id(const char *prefix, const uint8_t *id) {
    char hex[IPS_NODE_ID_LEN * 2 + 1];
    for (int i = 0; i < IPS_NODE_ID_LEN; i++) {
        sprintf(&hex[i * 2], "%02x", id[i]);
    }
    hex[IPS_NODE_ID_LEN * 2] = '\0';
    ESP_LOGI(TAG, "%s%s", prefix, hex);
}

void node_id_store_init(void) {
    nvs_handle_t handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READONLY, &handle);
    if (err != ESP_OK) {
        memset(g_nodeId, 0, IPS_NODE_ID_LEN);
        ESP_LOGW(TAG, "\xE2\x9A\xA0 NOT PROVISIONED - no NVS namespace, using default (all zeros).");
        ESP_LOGW(TAG, "Send 'SET_ID:<hex>' over Serial to provision this node.");
        return;
    }

    size_t required_size = IPS_NODE_ID_LEN;
    err = nvs_get_blob(handle, NVS_KEY_NODE_ID, g_nodeId, &required_size);
    nvs_close(handle);

    if (err == ESP_OK && required_size == IPS_NODE_ID_LEN) {
        log_node_id("Loaded Node ID from NVS: ", g_nodeId);
    } else {
        memset(g_nodeId, 0, IPS_NODE_ID_LEN);
        ESP_LOGW(TAG, "\xE2\x9A\xA0 NOT PROVISIONED - no Node ID in NVS, using default (all zeros).");
        ESP_LOGW(TAG, "Send 'SET_ID:<hex>' over Serial to provision this node.");
    }
}

bool node_id_store_save(const uint8_t new_id[IPS_NODE_ID_LEN]) {
    nvs_handle_t handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "nvs_open (RW) فشل: %s", esp_err_to_name(err));
        return false;
    }

    err = nvs_set_blob(handle, NVS_KEY_NODE_ID, new_id, IPS_NODE_ID_LEN);
    if (err == ESP_OK) {
        err = nvs_commit(handle);
    }
    nvs_close(handle);

    if (err != ESP_OK) {
        ESP_LOGE(TAG, "حفظ node_id فشل: %s", esp_err_to_name(err));
        return false;
    }

    log_node_id("New Node ID saved to NVS: ", new_id);
    return true;
}

bool node_id_store_is_provisioned(void) {
    for (int i = 0; i < IPS_NODE_ID_LEN; i++) {
        if (g_nodeId[i] != 0) return true;
    }
    return false;
}
