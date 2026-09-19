#pragma once

#include "esp_err.h"

/**
 * ota_receiver.h - استقبال فيرموير جديد من الـPC عبر Serial
 * والتحقق من الـhash قبل التثبيت
 */

// قيمة "magic" بتحدد بداية رسالة OTA - عشان لو فيه garbage في السيريال
// ما نخبطش الحسابات
#define IPS_OTA_MAGIC 0xABCD1234

// بروتوكول الأوامر:
// PC -> Root: OTA_START:<size>:<sha256_hex>\n
// Root -> PC: OTA_READY\n (بيوقف health JSON مؤقتاً)
// Root -> PC: OTA_ERROR:<reason>\n

// PC -> Root: <binary chunk 4KB at a time>
// Root -> PC: OTA_PROGRESS:<bytes_received>\n

// PC -> Root: OTA_END\n
// Root -> PC: OTA_DONE\n (ثم reboot)
// Root -> PC: OTA_ERROR:<reason>\n

#include "esp_ota_ops.h"
#include "esp_partition.h"
#include "mbedtls/sha256.h"

typedef struct {
    uint32_t size;           // الحجم الكلي للفيرموير (بايت)
    uint32_t received;       // كام بايت استقبلنا لحد دلوقتي
    uint8_t sha256[32];      // الـhash المتوقع (من PC)
    uint8_t calculated[32];  // الـhash اللي احنا حسبناه أول بأول
    const esp_partition_t *update_partition;
    esp_ota_handle_t ota_handle;
    mbedtls_sha256_context sha256_ctx;
    char fw_version[32];     // نسخة الفيرموير (للـlogging + NVS)
    uint8_t in_progress;     // هل في جلسة OTA شغالة دلوقتي؟
} ips_ota_session_t;

/**
 * بيهيّئ session OTA جديدة (بتنادى من serial_input.c لما PC بتبعت OTA_START)
 */
esp_err_t ips_ota_receiver_start(uint32_t size, const uint8_t sha256[32], const char *version);

/**
 * بتكتب chunk من الفيرموير لـ OTA partition وبتحدّث الـhash على الطاير
 */
esp_err_t ips_ota_receiver_write_chunk(const uint8_t *data, uint32_t size);

/**
 * بتخلص session OTA - بتتحقق من الـhash، بتظبط boot partition،
 * وبتحفظ معلومات الفيرموير في NVS (عشان ota_relay.c تستخدمها بعد reboot)
 */
esp_err_t ips_ota_receiver_finish(void);

/**
 * بتلغي session OTA الحالية (مثلاً لو حصل timeout أو error)
 */
void ips_ota_receiver_abort(void);

/**
 * بترجع session الـOTA الحالية (أو NULL لو ما في جلسة شغالة)
 */
ips_ota_session_t *ips_ota_receiver_get_session(void);
