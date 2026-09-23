#include "ota_apply.h"

#include "driver/gpio.h"
#include "esp_log.h"
#include "esp_mesh_lite.h"
#include "esp_ota_ops.h"
#include "esp_partition.h"
#include "esp_system.h"

#include "config.h"

static const char *TAG = "ota_apply";

static esp_ota_handle_t s_update_handle = 0;
static const esp_partition_t *s_next_partition = NULL;
static uint8_t s_ota_led_state = 0;

// بتتنادى كل ما جزء من الفيرموير الجديد يوصل من الـRoot عبر الـmesh.
static esp_err_t get_file_cb(esp_mesh_lite_lan_ota_file_transfer_param_t *param) {
    if (s_update_handle == 0) {
        s_next_partition = esp_ota_get_next_update_partition(NULL);
        if (!s_next_partition) {
            ESP_LOGE(TAG, "مفيش partition تاني فاضي للـOTA على الجهاز ده");
            return ESP_FAIL;
        }
        esp_err_t err = esp_ota_begin(s_next_partition, OTA_WITH_SEQUENTIAL_WRITES, &s_update_handle);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "esp_ota_begin فشل: %s", esp_err_to_name(err));
            s_update_handle = 0;
            return err;
        }
        ESP_LOGI(TAG, "بدأ استقبال فيرموير جديد (%s) - الحجم الكلي: %d بايت",
                 param->fw_version ? param->fw_version : "?", param->filesize);
    }

    // وميض سريع على لمبة GPIO 2 لتأكيد استقبال فلاش الفيرموير الجديد حياً
    s_ota_led_state = !s_ota_led_state;
    gpio_set_level(IPS_LED_GPIO, s_ota_led_state);

    return esp_ota_write(s_update_handle, param->data, param->data_size);
}

// بتتنادى لما الفيرموير يوصل كامل وسليم (المكتبة بتتأكد من التطابق قبل
// ما تنادي الدالة دي - راجع ESP_MESH_LITE_EVENT_OTA_CHECKSUM_ERR لو
// حصل فشل بدل كده).
static esp_err_t get_file_done_cb(void) {
    esp_err_t err = esp_ota_end(s_update_handle);
    s_update_handle = 0;
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_ota_end فشل: %s", esp_err_to_name(err));
        return err;
    }

    err = esp_ota_set_boot_partition(s_next_partition);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_ota_set_boot_partition فشل: %s", esp_err_to_name(err));
        return err;
    }

    // إضاءة الليد بشكل ثابت قبل إعادة التشغيل الفورية
    gpio_set_level(IPS_LED_GPIO, 1);

    ESP_LOGI(TAG, "الفيرموير الجديد اتحمّل بنجاح - هيعيد التشغيل دلوقتي "
                  "(هيرجع تلقائيًا للنسخة القديمة لو النسخة الجديدة عملت crash - "
                  "راجع CONFIG_BOOTLOADER_APP_ROLLBACK_ENABLE في OTA_PLAN.md)");
    esp_restart();
    return ESP_OK;
}

void ota_apply_init(void) {
    static esp_mesh_lite_lan_ota_file_transfer_cb_t cb = {
        // الـNode عندنا مستقبل بس دلوقتي - مش بيوزّع لنودز تانية بعده
        // (relay متعدد القفزات لسه مش مدعوم - راجع OTA_PLAN.md).
        .provide_file_cb = NULL,
        .get_file_cb = get_file_cb,
        .get_file_done = get_file_done_cb,
    };
    esp_mesh_lite_ota_register_file_transfer_cb(&cb);
    ESP_LOGI(TAG, "ota_apply جاهز - مستني فيرموير جديد لو الـRoot وزّع حاجة.");
}
