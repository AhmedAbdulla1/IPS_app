#include "ota_relay.h"

#include <stdio.h>
#include <string.h>

#include "esp_log.h"
#include "esp_mesh_lite.h"
#include "esp_ota_ops.h"
#include "esp_partition.h"
#include "esp_timer.h"
#include "nvs.h"

#include "config.h"
#include "health_table.h"

static const char *TAG = "ota_relay";

static uint32_t s_target_size = 0;
static uint8_t s_target_major = 0;
static uint8_t s_target_minor = 0;
static char s_target_version[16] = {0};
static bool s_relay_active = false;

// بتتنادى من مكتبة mesh_lite لما نود تطلب قطعة من ملف الفيرموير
static esp_err_t provide_file_cb(esp_mesh_lite_lan_ota_file_transfer_param_t *param) {
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

static esp_err_t ips_ota_relay_broadcast_announce(void) {
    if (s_target_size == 0) return ESP_ERR_INVALID_STATE;

    ips_ota_announce_t ann = {
        .size = s_target_size,
        .fw_major = s_target_major,
        .fw_minor = s_target_minor,
    };
    strlcpy(ann.version, s_target_version, sizeof(ann.version));

    esp_mesh_lite_msg_config_t conf = {0};
    conf.raw_msg.msg_id = IPS_MSG_ID_OTA_ANNOUNCE;
    conf.raw_msg.expect_resp_msg_id = 0;
    conf.raw_msg.max_retry = 0;
    conf.raw_msg.data = (const uint8_t *)&ann;
    conf.raw_msg.size = sizeof(ann);
    conf.raw_msg.raw_resend = esp_mesh_lite_send_broadcast_raw_msg_to_child;

    esp_err_t err = esp_mesh_lite_send_msg(ESP_MESH_LITE_RAW_MSG, &conf);
    ESP_LOGI(TAG, "📢 [Mesh-OTA] بث إعلان الفيرموير v%d.%d (حجم: %u بايت) للنودز: %s",
             s_target_major, s_target_minor, (unsigned)s_target_size, esp_err_to_name(err));
    return err;
}

esp_err_t ips_ota_relay_start(uint32_t size, const char *version) {
    ESP_LOGI(TAG, "🚀 بدء توزيع فيرموير الـNodes عبر الـMesh (الحجم: %u بايت، الإصدار: %s)...",
             (unsigned)size, version ? version : "new");

    int maj = 1, min = 0;
    if (version) {
        sscanf(version, "%d.%d", &maj, &min);
    }
    s_target_major = (uint8_t)maj;
    s_target_minor = (uint8_t)min;
    s_target_size = size;
    strlcpy(s_target_version, version ? version : "1.0", sizeof(s_target_version));
    s_relay_active = true;

    // تسجيل إصدار الفيرموير في مكتبة mesh-lite حتى تقبل طلبات النودز لهذا الإصدار
    esp_mesh_lite_lan_ota_set_file_name(s_target_version);

    // بث الإعلان فوراً
    ips_ota_relay_broadcast_announce();
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

void ips_ota_relay_tick(void) {
    if (s_target_size == 0) return;

    size_t total = ips_health_table_count();
    size_t outdated_nodes = 0;
    size_t active_nodes = 0;

    int64_t now_us = esp_timer_get_time();
    int64_t timeout_us = 10000000LL; // 10 ثواني كحد أقصى لاعتبار النود نشطة

    for (size_t i = 0; i < total; i++) {
        const ips_health_entry_t *e = ips_health_table_get(i);
        if (e && e->in_use && (now_us - e->last_seen_us < timeout_us)) {
            active_nodes++;
            if (e->fw_major < s_target_major || (e->fw_major == s_target_major && e->fw_minor < s_target_minor)) {
                outdated_nodes++;
            }
        }
    }

    if (outdated_nodes > 0) {
        // نود متصلة تحتاج تحديث (سواء انضمت متأخراً بعد الرفع أو لم تكتمل ترقيتها بعد)
        s_relay_active = true;
        esp_mesh_lite_lan_ota_set_file_name(s_target_version);

        static int s_tick_counter = 0;
        if (++s_tick_counter % 2 == 0) {
            ESP_LOGI(TAG, "📢 [Mesh-OTA] تم رصد %u نود بإصدار قديم - جاري بث إعلان v%s...",
                     (unsigned)outdated_nodes, s_target_version);
            ips_ota_relay_broadcast_announce();
        }
    } else if (s_relay_active && active_nodes > 0) {
        // كل النودز النشطة حالياً محدثة لأحدث إصدار
        ESP_LOGI(TAG, "🎉 [Mesh-OTA] جميع النودز النشطة (%u) محدثة إلى الإصدار v%d.%d بنجاح!",
                 (unsigned)active_nodes, s_target_major, s_target_minor);
        s_relay_active = false;
        clear_relay_pending();
    }
}

void ips_ota_relay_init(void) {
    // تسجيل provide_file_cb دائماً عند تشغيل الـRoot حتى يكون مستعداً لخدمة النودز
    static esp_mesh_lite_lan_ota_file_transfer_cb_t s_cb = {
        .provide_file_cb = provide_file_cb,
        .get_file_cb = NULL,
        .get_file_done = NULL,
    };
    esp_mesh_lite_ota_register_file_transfer_cb(&s_cb);

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

    if (size > 0) {
        int maj = 1, min = 0;
        sscanf(fw_version, "%d.%d", &maj, &min);
        s_target_major = (uint8_t)maj;
        s_target_minor = (uint8_t)min;
        s_target_size = size;
        strlcpy(s_target_version, fw_version, sizeof(s_target_version));
        esp_mesh_lite_lan_ota_set_file_name(s_target_version);
        if (pending) {
            s_relay_active = true;
            ips_ota_relay_broadcast_announce();
        }
    }
}
