#include "ota_relay.h"

#include <string.h>

#include "esp_log.h"
#include "esp_mesh_lite.h"
#include "esp_ota_ops.h"
#include "esp_partition.h"
#include "nvs.h"

#include "config.h"

static const char *TAG = "ota_relay";

// بتتنادى من مكتبة mesh_lite لما تحتاج تبعت "جزء" من ملف الفيرموير
// لأي Node طالبها. بنقرا من الـpartition اللي الـRoot شغال منها دلوقتي
// (يعني نفس النسخة الجديدة اللي هو نفسه اتفلش بيها - راجع ota_receiver.c).
// نفس الـpattern الموثّق في esp_mesh_lite_core.h (تعليق
// esp_mesh_lite_ota_register_file_transfer_cb).
static esp_err_t provide_file_cb(esp_mesh_lite_lan_ota_file_transfer_param_t *param) {
    // نقرأ من الـpartition التي كُتب فيها فيرموير الـNode (الـpartition غير الفعالة على الـRoot)
    const esp_partition_t *node_part = esp_ota_get_next_update_partition(NULL);
    if (!node_part) {
        ESP_LOGE(TAG, "provide_file_cb: مفيش partition لفيرموير الـNode؟!");
        return ESP_FAIL;
    }
    esp_err_t ret = esp_partition_read(node_part, param->offset, param->data, param->data_size);
    if (ret == ESP_OK) {
        int pct = param->filesize > 0 ? (param->offset * 100) / param->filesize : 0;
        if (param->offset == 0 || (param->offset % 131072 == 0) || (param->offset + param->data_size >= param->filesize)) {
            ESP_LOGI(TAG, "📡 [Mesh-OTA] نقل بيانات للنودز: %d%% (offset: %d / %d)", pct, param->offset, param->filesize);
        }
    }
    return ret;
}

static void clear_relay_pending(void) {
    nvs_handle_t h;
    if (nvs_open(IPS_OTA_NVS_NAMESPACE, NVS_READWRITE, &h) != ESP_OK) return;
    nvs_set_u8(h, IPS_OTA_NVS_KEY_PENDING, 0);
    nvs_commit(h);
    nvs_close(h);
}

esp_err_t ips_ota_relay_start(uint32_t size, const char *version) {
    ESP_LOGI(TAG, "🚀 بدء توزيع فيرموير الـNodes عبر الـMesh (الحجم: %u بايت، الإصدار: %s)...",
             (unsigned)size, version ? version : "new");

    static esp_mesh_lite_lan_ota_file_transfer_cb_t s_cb = {
        .provide_file_cb = provide_file_cb,
        .get_file_cb = NULL,
        .get_file_done = NULL,
    };
    esp_mesh_lite_ota_register_file_transfer_cb(&s_cb);

    esp_mesh_lite_file_transmit_config_t transmit_config = {
        .type = ESP_MESH_LITE_OTA_TRANSMIT_FIRMWARE,
        .size = size,
        .extern_url_ota_cb = NULL,
    };
    strlcpy(transmit_config.fw_version, version ? version : "new", sizeof(transmit_config.fw_version));

    esp_err_t start_err = esp_mesh_lite_transmit_file_start(&transmit_config);
    if (start_err != ESP_OK) {
        ESP_LOGE(TAG, "esp_mesh_lite_transmit_file_start فشل: %s", esp_err_to_name(start_err));
        return start_err;
    }

    ESP_LOGI(TAG, "✅ تم إطلاق توزيع الـOTA عبر الميش بنجاح!");
    return ESP_OK;
}

esp_err_t ips_ota_relay_redistribute(void) {
    nvs_handle_t h;
    esp_err_t err = nvs_open(IPS_OTA_NVS_NAMESPACE, NVS_READONLY, &h);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "لا يوجد فيرموير مخزن في NVS");
        return ESP_ERR_NOT_FOUND;
    }

    uint32_t size = 0;
    char fw_version[32] = {0};
    size_t ver_len = sizeof(fw_version);

    nvs_get_u32(h, IPS_OTA_NVS_KEY_SIZE, &size);
    nvs_get_str(h, IPS_OTA_NVS_KEY_VERSION, fw_version, &ver_len);
    nvs_close(h);

    if (size == 0) {
        ESP_LOGW(TAG, "حجم الفيرموير المخزن 0 بايت");
        return ESP_ERR_NOT_FOUND;
    }

    ESP_LOGI(TAG, "🔄 إعادة توزيع الفيرموير المخزن في الفلاش (الحجم: %u، الإصدار: %s)...",
             (unsigned)size, fw_version);
    return ips_ota_relay_start(size, fw_version);
}

void ips_ota_relay_init(void) {
    nvs_handle_t h;
    esp_err_t err = nvs_open(IPS_OTA_NVS_NAMESPACE, NVS_READONLY, &h);
    if (err != ESP_OK) {
        return;
    }

    uint8_t pending = 0;
    uint32_t size = 0;
    char fw_version[32] = {0};
    size_t ver_len = sizeof(fw_version);

    nvs_get_u8(h, IPS_OTA_NVS_KEY_PENDING, &pending);
    nvs_get_u32(h, IPS_OTA_NVS_KEY_SIZE, &size);
    nvs_get_str(h, IPS_OTA_NVS_KEY_VERSION, fw_version, &ver_len);
    nvs_close(h);

    if (!pending || size == 0) return;

    ips_ota_relay_start(size, fw_version);
    clear_relay_pending();
}

