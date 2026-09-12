#include "provisioning.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>

#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/uart.h"
#include "driver/uart_vfs.h"
#include "sdkconfig.h"

#include "ble_node.h"
#include "config.h"
#include "node_id_store.h"

static const char *TAG = "provisioning";

static void print_node_id(const uint8_t *id) {
    char hex[IPS_NODE_ID_LEN * 2 + 1];
    for (int i = 0; i < IPS_NODE_ID_LEN; i++) {
        sprintf(&hex[i * 2], "%02x", id[i]);
    }
    hex[IPS_NODE_ID_LEN * 2] = '\0';
    printf("%s\n", hex);
}

static int hex_val(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

// بيقبل 1-32 hex chars زي الأصلي، وبيعمل zero-pad من الشمال.
static bool parse_hex_node_id(const char *hex, uint8_t *out_bytes) {
    size_t len = strlen(hex);
    if (len == 0 || len > 32) return false;

    char padded[33];
    size_t pad_len = 32 - len;
    memset(padded, '0', pad_len);
    memcpy(padded + pad_len, hex, len);
    padded[32] = '\0';

    for (int i = 0; i < 16; i++) {
        int hi = hex_val(padded[i * 2]);
        int lo = hex_val(padded[i * 2 + 1]);
        if (hi < 0 || lo < 0) return false;
        out_bytes[i] = (uint8_t)((hi << 4) | lo);
    }
    return true;
}

static void handle_command(char *line) {
    // trim trailing \r\n ومسافات.
    size_t len = strlen(line);
    while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r' ||
                        line[len - 1] == ' ')) {
        line[--len] = '\0';
    }
    if (len == 0) return;

    if (strcasecmp(line, "GET_ID") == 0) {
        printf("[PROVISION] Current Node ID: ");
        print_node_id(g_nodeId);
        return;
    }

    if (strncasecmp(line, "SET_ID:", 7) == 0) {
        const char *hex_part = line + 7;
        uint8_t new_id[IPS_NODE_ID_LEN];

        if (!parse_hex_node_id(hex_part, new_id)) {
            printf("[PROVISION] ERROR: invalid hex value. Use 1-32 hex chars, "
                   "e.g. SET_ID:4 or SET_ID:3e8\n");
            return;
        }

        if (!node_id_store_save(new_id)) {
            printf("[PROVISION] ERROR: failed to save to NVS.\n");
            return;
        }

        printf("[PROVISION] New Node ID saved to NVS. Rebooting to apply...\n");
        fflush(stdout);
        vTaskDelay(pdMS_TO_TICKS(100));
        esp_restart();
        return;
    }

    printf("[PROVISION] Unknown command. Supported: SET_ID:<hex>, GET_ID\n");
}

static void provisioning_task(void *arg) {
    (void)arg;
    char line[80];

    while (1) {
        if (fgets(line, sizeof(line), stdin) != NULL) {
            handle_command(line);
        }
        // fgets بيبلوك لحد ما سطر يوصل - مفيش داعي لـvTaskDelay هنا.
    }
}

// بيفعّل UART driver حقيقي (interrupt-driven) بدل الـblocking polling
// الافتراضي اللي بيستخدمه fgets/stdin من غير driver. من غير ده، الـread
// بيعمل busy-poll على الـCPU اللي شغال عليه الـtask ده، وبيمنع IDLE task
// بتاعت نفس الـcore من الاشتغال → task watchdog بيطلع (شوهد فعليًا في
// اختبار hardware: IDLE1 مش بيتعمله reset لما provisioning_task شغال
// على CPU1 وبيعمل fgets بلوكينج).
static void provisioning_uart_init(void) {
    const uart_config_t uart_config = {
        .baud_rate = CONFIG_ESP_CONSOLE_UART_BAUDRATE,
        .data_bits = UART_DATA_8_BITS,
        .parity    = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };
    ESP_ERROR_CHECK(uart_driver_install(CONFIG_ESP_CONSOLE_UART_NUM, 256, 0, 0, NULL, 0));
    ESP_ERROR_CHECK(uart_param_config(CONFIG_ESP_CONSOLE_UART_NUM, &uart_config));
    uart_vfs_dev_use_driver(CONFIG_ESP_CONSOLE_UART_NUM);
}

void provisioning_task_start(void) {
    provisioning_uart_init();
    xTaskCreate(provisioning_task, "provisioning", 4096, NULL, 5, NULL);
    ESP_LOGI(TAG, "Provisioning task شغال - في انتظار أوامر SET_ID/GET_ID.");
}
