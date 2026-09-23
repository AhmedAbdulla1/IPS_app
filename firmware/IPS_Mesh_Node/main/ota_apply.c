#include "ota_apply.h"

#include <string.h>
#include "driver/gpio.h"
#include "esp_log.h"
#include "esp_mesh_lite.h"
#include "esp_ota_ops.h"
#include "esp_partition.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "config.h"

static const char *TAG = "ota_apply";

static esp_ota_handle_t s_update_handle = 0;
static const esp_partition_t *s_next_partition = NULL;
static uint8_t s_ota_led_state = 0;
static uint32_t s_expected_size = 0;
static uint32_t s_total_written = 0;
static bool s_ota_in_progress = false;

// بتتنادى كل ما جزء من الفيرموير الجديد يوصل من الـRoot عبر الـmesh.
static esp_err_t get_file_cb(esp_mesh_lite_lan_ota_file_transfer_param_t *param) {
    if (s_update_handle == 0) {
        s_next_partition = esp_ota_get_next_update_partition(NULL);
        if (!s_next_partition) {
            ESP_LOGE(TAG, "مفيش partition تاني فاضي للـOTA على الجهاز ده");
            s_ota_in_progress = false;
            return ESP_FAIL;
        }
        esp_err_t err = esp_ota_begin(s_next_partition, OTA_WITH_SEQUENTIAL_WRITES, &s_update_handle);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "esp_ota_begin فشل: %s", esp_err_to_name(err));
            s_update_handle = 0;
            s_ota_in_progress = false;
            return err;
        }
        s_total_written = 0;
        ESP_LOGI(TAG, "🚀 بدأ استقبال فيرموير جديد (%s) - الحجم المتوقع: %u بايت",
                 param->fw_version ? param->fw_version : "?", (unsigned)s_expected_size);
    }

    // تقييد الكتابة بالحجم الفعلي للفيرموير لمنع كتابة padding الـ64KB التي تسبب فشل esp_ota_end
    size_t bytes_to_write = param->data_size;
    if (s_expected_size > 0 && (s_total_written + bytes_to_write > s_expected_size)) {
        if (s_total_written >= s_expected_size) {
            bytes_to_write = 0;
        } else {
            bytes_to_write = s_expected_size - s_total_written;
        }
    }

    if (bytes_to_write > 0) {
        esp_err_t write_err = esp_ota_write(s_update_handle, param->data, bytes_to_write);
        if (write_err != ESP_OK) {
            ESP_LOGE(TAG, "esp_ota_write فشل: %s", esp_err_to_name(write_err));
            s_ota_in_progress = false;
            return write_err;
        }
        s_total_written += bytes_to_write;
    }

    // وميض سريع على لمبة GPIO 2 لتأكيد استقبال فلاش الفيرموير الجديد حياً
    s_ota_led_state = !s_ota_led_state;
    gpio_set_level(IPS_LED_GPIO, s_ota_led_state);

    if (s_expected_size > 0) {
        int pct = (s_total_written * 100) / s_expected_size;
        if ((s_total_written % 65536 < param->data_size) || (s_total_written >= s_expected_size)) {
            ESP_LOGI(TAG, "📥 [Mesh-OTA] تقدم التحميل: %d%% (%u / %u بايت)",
                     pct, (unsigned)s_total_written, (unsigned)s_expected_size);
        }
    }

    return ESP_OK;
}

// بتتنادى لما الفيرموير يوصل كامل وسليم
static esp_err_t get_file_done_cb(void) {
    ESP_LOGI(TAG, "📥 اكتمال نقل بيانات الفيرموير (إجمالي المكتوب: %u بايت). جاري التحقق من الفيرموير...",
             (unsigned)s_total_written);

    esp_err_t err = esp_ota_end(s_update_handle);
    s_update_handle = 0;
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "❌ esp_ota_end فشل التحقق من الـSHA256 والصورة: %s", esp_err_to_name(err));
        s_ota_in_progress = false;
        return err;
    }

    err = esp_ota_set_boot_partition(s_next_partition);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "❌ esp_ota_set_boot_partition فشل: %s", esp_err_to_name(err));
        s_ota_in_progress = false;
        return err;
    }

    // إضاءة الليد بشكل ثابت قبل إعادة التشغيل الفورية
    gpio_set_level(IPS_LED_GPIO, 1);

    ESP_LOGI(TAG, "🎉 تم تحديث الفيرموير بنجاح! جاري إعادة التشغيل الآن لتطبيق التحديث...");
    vTaskDelay(pdMS_TO_TICKS(500));
    esp_restart();
    return ESP_OK;
}

static void ota_apply_on_announce(const ips_ota_announce_t *ann) {
    if (s_ota_in_progress) {
        ESP_LOGD(TAG, "OTA جاري بالفعل - تجاهل الإعلان");
        return;
    }

    if (ann->fw_major == IPS_FW_VERSION_MAJOR && ann->fw_minor == IPS_FW_VERSION_MINOR) {
        ESP_LOGD(TAG, "الجهاز يعمل بالفعل بالإصدار المعلن (v%d.%d) - لا داعي للتحديث",
                 ann->fw_major, ann->fw_minor);
        return;
    }

    if (ann->size == 0) {
        ESP_LOGW(TAG, "حجم الفيرموير المعلن 0 بايت - تم الإلغاء");
        return;
    }

    ESP_LOGI(TAG, "📢 استلام إشعار فيرموير جديد: v%d.%d (حجم: %u بايت). الحالي: v%d.%d. جاري سحب الفيرموير عبر الميش...",
             ann->fw_major, ann->fw_minor, (unsigned)ann->size,
             IPS_FW_VERSION_MAJOR, IPS_FW_VERSION_MINOR);

    s_expected_size = ann->size;
    s_total_written = 0;
    s_ota_in_progress = true;

    esp_mesh_lite_file_transmit_config_t transmit_config = {
        .type = ESP_MESH_LITE_OTA_TRANSMIT_FIRMWARE,
        .size = ann->size,
        .extern_url_ota_cb = NULL,
    };
    strlcpy(transmit_config.fw_version, ann->version, sizeof(transmit_config.fw_version));

    esp_err_t err = esp_mesh_lite_transmit_file_start(&transmit_config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "❌ esp_mesh_lite_transmit_file_start فشل: %s", esp_err_to_name(err));
        s_ota_in_progress = false;
    }
}

static esp_err_t handle_ota_announce_raw(uint8_t *data, uint32_t len,
                                         uint8_t **out_data, uint32_t *out_len,
                                         uint32_t seq) {
    (void)seq;
    if (out_data) *out_data = NULL;
    if (out_len) *out_len = 0;

    if (data != NULL && len >= sizeof(ips_ota_announce_t)) {
        ota_apply_on_announce((const ips_ota_announce_t *)data);
    }
    return ESP_OK;
}

static const esp_mesh_lite_raw_msg_action_t s_ota_announce_action = {
    .msg_id = IPS_MSG_ID_OTA_ANNOUNCE,
    .resp_msg_id = 0,
    .raw_process = handle_ota_announce_raw,
};

void ota_apply_init(void) {
    static esp_mesh_lite_lan_ota_file_transfer_cb_t cb = {
        .provide_file_cb = NULL,
        .get_file_cb = get_file_cb,
        .get_file_done = get_file_done_cb,
    };
    esp_mesh_lite_ota_register_file_transfer_cb(&cb);

    esp_err_t err = esp_mesh_lite_raw_msg_action_list_register(&s_ota_announce_action);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "فشل تسجيل مستمع إعلانات OTA: %s", esp_err_to_name(err));
    }

    ESP_LOGI(TAG, "ota_apply جاهز ومستمع لإعلانات الفيرموير عبر الميش (v%d.%d).",
             IPS_FW_VERSION_MAJOR, IPS_FW_VERSION_MINOR);
}
