#include "serial_output.h"

#include <stdio.h>
#include <string.h>
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "lwip/sockets.h"
#include "esp_log.h"

#include "config.h"
#include "health_table.h"
#include "ota_receiver.h"
#include "ota_relay.h"

static int _tcp_client_sock = -1;
static SemaphoreHandle_t _tcp_mutex = NULL;

static const char *TAG = "serial_output";

static void node_id_to_hex(const uint8_t *node_id, char *out /* >= 33 bytes */) {
    static const char hex_chars[] = "0123456789abcdef";
    for (int i = 0; i < IPS_NODE_ID_LEN; i++) {
        out[i * 2] = hex_chars[(node_id[i] >> 4) & 0x0F];
        out[i * 2 + 1] = hex_chars[node_id[i] & 0x0F];
    }
    out[IPS_NODE_ID_LEN * 2] = '\0';
}

static void tcp_send_line(const char *line) {
    if (_tcp_client_sock < 0) return;
    if (xSemaphoreTake(_tcp_mutex, pdMS_TO_TICKS(100)) != pdTRUE) return;
    
    int ret = send(_tcp_client_sock, line, strlen(line), MSG_DONTWAIT);
    if (ret < 0) {
        close(_tcp_client_sock);
        _tcp_client_sock = -1;
    }
    xSemaphoreGive(_tcp_mutex);
}

static void tcp_server_task(void *arg) {
    (void)arg;
    int server_sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (server_sock < 0) {
        ESP_LOGE(TAG, "Socket failed");
        vTaskDelete(NULL);
        return;
    }
    
    int opt = 1;
    setsockopt(server_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(9998);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    
    if (bind(server_sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        ESP_LOGE(TAG, "Bind failed");
        close(server_sock);
        vTaskDelete(NULL);
        return;
    }
    
    if (listen(server_sock, 1) < 0) {
        ESP_LOGE(TAG, "Listen failed");
        close(server_sock);
        vTaskDelete(NULL);
        return;
    }
    
    ESP_LOGI(TAG, "TCP listening on port 9998");
    
    while (1) {
        struct sockaddr_in client_addr;
        socklen_t client_addr_len = sizeof(client_addr);
        
        int client_sock = accept(server_sock, (struct sockaddr *)&client_addr, &client_addr_len);
        if (client_sock >= 0) {
            if (xSemaphoreTake(_tcp_mutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
                if (_tcp_client_sock >= 0) {
                    close(_tcp_client_sock);
                }
                _tcp_client_sock = client_sock;
                xSemaphoreGive(_tcp_mutex);
                ESP_LOGI(TAG, "TCP Client connected successfully");
            } else {
                close(client_sock);
            }
        }
    }
}

static void serial_output_task(void *arg) {
    (void)arg;
    char node_id_hex[IPS_NODE_ID_LEN * 2 + 1];
    char line_buffer[384];

    while (1) {
        if (ips_ota_receiver_get_session() != NULL) {
            // جلسة OTA نشطة الآن - إيقاف طباعة الـ JSON مؤقتًا لمنع التداخل على السيريال
            vTaskDelay(pdMS_TO_TICKS(500));
            continue;
        }

        // مسح أي نودز توقفت عن إرسال heartbeats لأكثر من 12 ثانية
        ips_health_table_purge_expired(12000000LL);

        // إرسال معلومات الـ Root أولاً حتى يعرف الداشبورد إصدار الـ Root وحالته
        snprintf(line_buffer, sizeof(line_buffer),
                 "{\"type\":\"root_info\",\"fw_major\":%u,\"fw_minor\":%u,\"layer\":1,\"uptime_s\":%lld}\n",
                 (unsigned)IPS_FW_VERSION_MAJOR,
                 (unsigned)IPS_FW_VERSION_MINOR,
                 (long long)(esp_timer_get_time() / 1000000LL));
        printf("%s", line_buffer);
        tcp_send_line(line_buffer);

        int64_t now_us = esp_timer_get_time();
        size_t count = ips_health_table_count();

        for (size_t i = 0; i < count; i++) {
            const ips_health_entry_t *entry = ips_health_table_get(i);
            if (entry == NULL) continue;

            node_id_to_hex(entry->node_id, node_id_hex);
            int64_t last_seen_ms = entry->last_seen_us / 1000;
            int64_t elapsed_ms = (now_us - entry->last_seen_us) / 1000;

            // حساب مهلة التوقف الديناميكية حسب الطبقة
            int64_t timeout_ms = IPS_BASE_TIMEOUT_MS + (entry->hop_count * IPS_PER_HOP_MARGIN_MS);
            bool is_online = (elapsed_ms <= timeout_ms);

            // إرسال سطر JSON نظيف وسهل البارسينج
            snprintf(line_buffer, sizeof(line_buffer),
                     "{\"type\":\"health\",\"node_id\":\"%s\",\"status\":\"%s\",\"hop_count\":%u,\"last_seen_ms\":%lld,\"fw_major\":%u,\"fw_minor\":%u}\n",
                     node_id_hex,
                     is_online ? "online" : "offline",
                     (unsigned)entry->hop_count,
                     (long long)last_seen_ms,
                     (unsigned)entry->fw_major,
                     (unsigned)entry->fw_minor);

            printf("%s", line_buffer);
            tcp_send_line(line_buffer);
        }
        fflush(stdout);

        // فحص دوري لنقل الفيرموير وإعادة بث الإعلان للنودز غير المحدثة
        ips_ota_relay_tick();

        vTaskDelay(pdMS_TO_TICKS(IPS_HEALTH_REPORT_INTERVAL_MS));
    }
}

void ips_serial_output_start(void) {
    _tcp_mutex = xSemaphoreCreateMutex();
    if (!_tcp_mutex) {
        ESP_LOGE(TAG, "Mutex creation failed");
        return;
    }
    
    xTaskCreate(tcp_server_task, "tcp_server", 4096, NULL, 5, NULL);
    xTaskCreate(serial_output_task, "health_serial_out", 4096, NULL, 5, NULL);
    ESP_LOGI(TAG, "Serial/TCP output started");
}
