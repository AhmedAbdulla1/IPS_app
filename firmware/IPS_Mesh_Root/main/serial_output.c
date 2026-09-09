#include "serial_output.h"

#include <stdio.h>
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "config.h"
#include "health_table.h"

static void node_id_to_hex(const uint8_t *node_id, char *out /* >= 33 bytes */) {
    static const char hex_chars[] = "0123456789abcdef";
    for (int i = 0; i < IPS_NODE_ID_LEN; i++) {
        out[i * 2] = hex_chars[(node_id[i] >> 4) & 0x0F];
        out[i * 2 + 1] = hex_chars[node_id[i] & 0x0F];
    }
    out[IPS_NODE_ID_LEN * 2] = '\0';
}

static void serial_output_task(void *arg) {
    (void)arg;
    char node_id_hex[IPS_NODE_ID_LEN * 2 + 1];

    while (1) {
        size_t count = ips_health_table_count();
        for (size_t i = 0; i < count; i++) {
            const ips_health_entry_t *entry = ips_health_table_get(i);
            if (entry == NULL) continue;

            node_id_to_hex(entry->node_id, node_id_hex);

            int64_t last_seen_ms = entry->last_seen_us / 1000;

            // status: بنبعت "online" دايمًا هنا - القرار النهائي
            // ONLINE/OFFLINE بيتحسب PC-side بناءً على last_seen_ms
            // وصيغة الـdynamic timeout (MESH_DESIGN.md §4.5)، مش هنا.
            // (طبعنا printf مباشرة، مش ESP_LOGI، عشان الـPC parser
            // يلاقي السطر يبدأ بـ"HEALTH:" بالظبط من غير prefix زيادة).
            printf("HEALTH:%s:online:%u:%lld\n",
                   node_id_hex,
                   (unsigned)entry->hop_count,
                   (long long)last_seen_ms);
        }
        fflush(stdout);

        vTaskDelay(pdMS_TO_TICKS(IPS_HEALTH_REPORT_INTERVAL_MS));
    }
}

void ips_serial_output_start(void) {
    xTaskCreate(serial_output_task, "health_serial_out", 4096, NULL, 5, NULL);
}
