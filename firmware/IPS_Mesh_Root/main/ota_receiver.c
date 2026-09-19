#include "ota_receiver.h"

#include <string.h>

#include "esp_log.h"
#include "esp_ota_ops.h"
#include "esp_partition.h"
#include "mbedtls/sha256.h"
#include "nvs.h"

#include "config.h"
#include "ota_relay.h"

static const char *TAG = "ota_receiver";

// session عام - واحدة بس في الوقت الواحد (مافيش concurrent OTA sessions)
static ips_ota_session_t g_session = {0};

esp_err_t ips_ota_receiver_start(uint32_t size, const uint8_t sha256[32], const char *version) {
    if (g_session.in_progress) {
        ESP_LOGW(TAG, "في جلسة OTA شغالة بالفعل - اتجاهل OTA_START الجديدة");
        return ESP_ERR_INVALID_STATE;
    }

    // جهز الـOTA partition الفاضية
    const esp_partition_t *next = esp_ota_get_next_update_partition(NULL);
    if (!next) {
        ESP_LOGE(TAG, "مفيش OTA partition فاضية");
        return ESP_ERR_NOT_FOUND;
    }

    ESP_LOGI(TAG, "بدء جلسة OTA: size=%u, version=%s, partition=%s", 
             (unsigned)size, version, next->label);

    esp_ota_handle_t ota_handle = 0;
    esp_err_t ret = esp_ota_begin(next, size, &ota_handle);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "فشل esp_ota_begin: %s", esp_err_to_name(ret));
        return ret;
    }

    // جهز session
    memset(&g_session, 0, sizeof(g_session));
    g_session.size = size;
    g_session.in_progress = 1;
    g_session.update_partition = next;
    g_session.ota_handle = ota_handle;
    memcpy(g_session.sha256, sha256, 32);
    strlcpy(g_session.fw_version, version, sizeof(g_session.fw_version));

    // ابدأ حساب الـsha256
    mbedtls_sha256_init(&g_session.sha256_ctx);
    mbedtls_sha256_starts(&g_session.sha256_ctx, 0); // 0 = SHA256

    ESP_LOGI(TAG, "✅ جلسة OTA جاهزة");
    return ESP_OK;
}

esp_err_t ips_ota_receiver_write_chunk(const uint8_t *data, uint32_t size) {
    if (!g_session.in_progress) {
        ESP_LOGW(TAG, "لا توجد جلسة OTA نشطة - تجاهل chunk");
        return ESP_ERR_INVALID_STATE;
    }

    if (g_session.received + size > g_session.size) {
        ESP_LOGE(TAG, "chunk كبير جداً: received=%u + chunk=%u > total=%u",
                 (unsigned)g_session.received, (unsigned)size, (unsigned)g_session.size);
        return ESP_ERR_INVALID_ARG;
    }

    esp_err_t ret = esp_ota_write(g_session.ota_handle, data, size);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "فشل esp_ota_write: %s", esp_err_to_name(ret));
        return ret;
    }

    // حدّث الـsha256
    mbedtls_sha256_update(&g_session.sha256_ctx, data, size);
    g_session.received += size;

    return ESP_OK;
}

esp_err_t ips_ota_receiver_finish(void) {
    if (!g_session.in_progress) {
        return ESP_ERR_INVALID_STATE;
    }

    if (g_session.received != g_session.size) {
        ESP_LOGE(TAG, "حجم الملف المستقبل (%u) لا يطابق المتوقع (%u)",
                 (unsigned)g_session.received, (unsigned)g_session.size);
        ips_ota_receiver_abort();
        return ESP_ERR_INVALID_SIZE;
    }

    // أكمل حساب الـsha256
    mbedtls_sha256_finish(&g_session.sha256_ctx, g_session.calculated);
    mbedtls_sha256_free(&g_session.sha256_ctx);

    // تحقق من الـhash
    if (memcmp(g_session.calculated, g_session.sha256, 32) != 0) {
        ESP_LOGE(TAG, "❌ SHA256 mismatch!");
        esp_ota_abort(g_session.ota_handle);
        g_session.in_progress = 0;
        return ESP_ERR_INVALID_CRC;
    }

    ESP_LOGI(TAG, "✅ SHA256 verified - الفيرموير صحيح");

    esp_err_t ret = esp_ota_end(g_session.ota_handle);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "فشل esp_ota_end: %s", esp_err_to_name(ret));
        g_session.in_progress = 0;
        return ret;
    }

    // [ملاحظة مهمة جداً]:
    // لا نستدعي esp_ota_set_boot_partition() لأن هذا الفيرموير مخصص لبوردات الـ Nodes!
    // الـ Root يجب أن يظل يعمل كـ Root ليوزع هذا الملف عبر الـ Mesh.

    // حفظ بيانات الفيرموير في NVS حتى تظل متاحة دائماً بعد انقطاع الباور وإعادة التشغيل
    nvs_handle_t h;
    if (nvs_open(IPS_OTA_NVS_NAMESPACE, NVS_READWRITE, &h) == ESP_OK) {
        nvs_set_u8(h, IPS_OTA_NVS_KEY_PENDING, 1);
        nvs_set_u32(h, IPS_OTA_NVS_KEY_SIZE, g_session.size);
        nvs_set_str(h, IPS_OTA_NVS_KEY_VERSION, g_session.fw_version);
        nvs_commit(h);
        nvs_close(h);
        ESP_LOGI(TAG, "💾 تم حفظ بيانات الفيرموير في NVS: size=%u, ver=%s",
                 (unsigned)g_session.size, g_session.fw_version);
    }

    ESP_LOGI(TAG, "✅ تم تخزين فيرموير الـNode في الفلاش بنجاح. بدء التوزيع المباشر عبر الـMesh...");
    ips_ota_relay_start(g_session.size, g_session.fw_version);

    g_session.in_progress = 0;
    return ESP_OK;
}

void ips_ota_receiver_abort(void) {
    if (g_session.in_progress) {
        mbedtls_sha256_free(&g_session.sha256_ctx);
        if (g_session.ota_handle) {
            esp_ota_abort(g_session.ota_handle);
        }
    }
    memset(&g_session, 0, sizeof(g_session));
    ESP_LOGW(TAG, "تم إلغاء جلسة OTA");
}

ips_ota_session_t *ips_ota_receiver_get_session(void) {
    return g_session.in_progress ? &g_session : NULL;
}
