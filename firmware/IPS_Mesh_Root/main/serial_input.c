#include "serial_input.h"

#include <stdio.h>
#include <string.h>

#include "driver/uart.h"
#include "driver/uart_vfs.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"

#include "config.h"
#include "ota_receiver.h"
#include "ota_relay.h"

static const char *TAG = "serial_input";

static uint8_t g_ota_chunk_buffer[4096]; // 4KB chunks
static uint32_t g_chunk_index = 0;       // كم بايت تم تجميعها في الـbuffer الحالي

void ips_serial_process_line(const char *line) {
    if (!line || strlen(line) == 0) return;

    // OTA_START:<size_decimal>:<sha256_hex_64chars>[:version]
    if (strncmp(line, "OTA_START:", 10) == 0) {
        const char *ptr = line + 10;
        unsigned long size_val = 0;
        uint8_t sha256[32];
        char sha256_hex[65];
        char version[32] = "unknown";

        int parsed = sscanf(ptr, "%lu:%64[^:\r\n]", &size_val, sha256_hex);
        if (parsed < 2 || strlen(sha256_hex) != 64) {
            ESP_LOGE(TAG, "OTA_START format invalid: %s", line);
            printf("OTA_ERROR:invalid_format\n");
            fflush(stdout);
            return;
        }

        uint32_t size = (uint32_t)size_val;

        // استخراج version إن وجد
        const char *v1 = strchr(ptr, ':');
        if (v1) {
            const char *v2 = strchr(v1 + 1, ':');
            if (v2) {
                sscanf(v2 + 1, "%31s", version);
            }
        }

        // تحويل hex string إلى bytes
        for (int i = 0; i < 32; i++) {
            sscanf(sha256_hex + 2 * i, "%2hhx", &sha256[i]);
        }

        esp_err_t ret = ips_ota_receiver_start(size, sha256, version);
        if (ret == ESP_OK) {
            g_chunk_index = 0;
            printf("OTA_READY\n");
            fflush(stdout);
        } else {
            printf("OTA_ERROR:start_failed\n");
            fflush(stdout);
        }
        return;
    }

    // OTA_ABORT
    if (strcmp(line, "OTA_ABORT") == 0) {
        ips_ota_receiver_abort();
        g_chunk_index = 0;
        printf("OTA_ABORTED\n");
        fflush(stdout);
        return;
    }

    // OTA_END
    if (strcmp(line, "OTA_END") == 0) {
        // اكتب أي بايتات متبقية في الـbuffer إن وجدت
        if (g_chunk_index > 0) {
            ips_ota_receiver_write_chunk(g_ota_chunk_buffer, g_chunk_index);
            g_chunk_index = 0;
        }

        // إنهاء الجلسة والتحقق من الـ SHA256 وبدء التوزيع التلقائي عبر الـMesh
        esp_err_t ret = ips_ota_receiver_finish();
        if (ret == ESP_OK) {
            printf("OTA_DONE\n");
            fflush(stdout);
        } else {
            printf("OTA_ERROR:verify_failed\n");
            fflush(stdout);
            ips_ota_receiver_abort();
        }
        return;
    }

    // GET_ROOT_INFO: طلب معلومات وإصدار الـRoot فوراً
    if (strcmp(line, "GET_ROOT_INFO") == 0) {
        printf("{\"type\":\"root_info\",\"fw_major\":%u,\"fw_minor\":%u,\"layer\":1,\"uptime_s\":%lld}\n",
               (unsigned)IPS_FW_VERSION_MAJOR,
               (unsigned)IPS_FW_VERSION_MINOR,
               (long long)(esp_timer_get_time() / 1000000LL));
        fflush(stdout);
        return;
    }

    // OTA_REDISTRIBUTE: إعادة توزيع الفيرموير المحفوظ في الفلاش دون الحاجة للرفع من جديد
    if (strcmp(line, "OTA_REDISTRIBUTE") == 0) {
        esp_err_t ret = ips_ota_relay_redistribute();
        if (ret == ESP_OK) {
            printf("OTA_RELAY_STARTED\n");
        } else {
            printf("OTA_ERROR:no_stored_firmware\n");
        }
        fflush(stdout);
        return;
    }

    // أي أسطر نصية أخرى يتم تجاهلها
}

void ips_serial_process_binary(const uint8_t *data, uint32_t len) {
    if (!data || len == 0) return;

    ips_ota_session_t *session = ips_ota_receiver_get_session();
    if (!session || !session->in_progress) {
        return;
    }

    uint32_t offset = 0;
    while (offset < len) {
        uint32_t to_copy = len - offset;
        if (g_chunk_index + to_copy > sizeof(g_ota_chunk_buffer)) {
            to_copy = sizeof(g_ota_chunk_buffer) - g_chunk_index;
        }

        memcpy(&g_ota_chunk_buffer[g_chunk_index], data + offset, to_copy);
        g_chunk_index += to_copy;
        offset += to_copy;

        // إذا امتلأ الـbuffer أو وصلنا لحجم الفيرموير الكلي المتوقع
        if (g_chunk_index == sizeof(g_ota_chunk_buffer) ||
            (session->received + g_chunk_index == session->size)) {
            esp_err_t ret = ips_ota_receiver_write_chunk(g_ota_chunk_buffer, g_chunk_index);
            if (ret == ESP_OK) {
                printf("OTA_PROGRESS:%u\n", (unsigned)session->received);
                fflush(stdout);
            } else {
                printf("OTA_ERROR:write_failed\n");
                fflush(stdout);
                ips_ota_receiver_abort();
                g_chunk_index = 0;
                return;
            }
            g_chunk_index = 0;
        }
    }
}

static void serial_input_uart_init(void) {
    if (!uart_is_driver_installed(CONFIG_ESP_CONSOLE_UART_NUM)) {
        const uart_config_t uart_config = {
            .baud_rate = CONFIG_ESP_CONSOLE_UART_BAUDRATE,
            .data_bits = UART_DATA_8_BITS,
            .parity    = UART_PARITY_DISABLE,
            .stop_bits = UART_STOP_BITS_1,
            .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
            .source_clk = UART_SCLK_DEFAULT,
        };
        ESP_ERROR_CHECK(uart_driver_install(CONFIG_ESP_CONSOLE_UART_NUM, 16384, 0, 0, NULL, 0));
        ESP_ERROR_CHECK(uart_param_config(CONFIG_ESP_CONSOLE_UART_NUM, &uart_config));
        uart_vfs_dev_use_driver(CONFIG_ESP_CONSOLE_UART_NUM);
    }
}

static void serial_input_task(void *arg) {
    (void)arg;
    uint8_t rx_buf[512];
    char line_buf[256];
    size_t line_pos = 0;

    while (1) {
        int len = uart_read_bytes(CONFIG_ESP_CONSOLE_UART_NUM, rx_buf, sizeof(rx_buf), pdMS_TO_TICKS(20));
        if (len <= 0) {
            continue;
        }

        ips_ota_session_t *session = ips_ota_receiver_get_session();
        bool is_binary = (session != NULL && session->in_progress &&
                          (session->received + g_chunk_index < session->size));

        int offset = 0;
        if (is_binary) {
            uint32_t needed = session->size - (session->received + g_chunk_index);
            uint32_t bin_bytes = (len > (int)needed) ? needed : (uint32_t)len;
            ips_serial_process_binary(rx_buf, bin_bytes);
            offset = bin_bytes;
        }

        // أي بايتات متبقية (أو كل البايتات إذا لم نكن في وضع الـ binary) تُعامل كأسطر نصية
        for (int i = offset; i < len; i++) {
            char c = (char)rx_buf[i];
            if (c == '\n') {
                line_buf[line_pos] = '\0';
                if (line_pos > 0 && line_buf[line_pos - 1] == '\r') {
                    line_buf[line_pos - 1] = '\0';
                }
                ips_serial_process_line(line_buf);
                line_pos = 0;
            } else if (c != '\r') {
                if (line_pos < sizeof(line_buf) - 1) {
                    line_buf[line_pos++] = c;
                } else {
                    line_pos = 0; // حماية من overflow
                }
            }
        }
    }
}

void ips_serial_input_start(void) {
    serial_input_uart_init();
    xTaskCreate(serial_input_task, "serial_input", 4096, NULL, 5, NULL);
    ESP_LOGI(TAG, "Serial input task شغال - جاهز لاستقبال أوامر OTA والفيرموير.");
}
