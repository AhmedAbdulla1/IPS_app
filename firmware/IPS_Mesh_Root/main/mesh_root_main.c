// فيرموير الـRoot - مسؤول عن:
//   1. تشغيل ESP-MESH-LITE في وضع root (معزول عن الإنترنت)
//   2. استقبال heartbeat من كل child nodes (Arms/Ring)
//   3. طباعة الحالة على الـSerial بروتوكول HEALTH:... عشان
//      pc_health_service يقرأها ويرفعها لـSupabase
//
// التصميم الكامل: ../../MESH_DESIGN.md
// حالة التنفيذ وTODOs مفتوحة: ../../MESH_PROGRESS.md

#include "esp_log.h"

#include "health_table.h"
#include "mesh_bridge.h"
#include "serial_output.h"

static const char *TAG = "ips_mesh_root";

void app_main(void) {
    ESP_LOGI(TAG, "=== IPS Mesh Root starting ===");

    ips_health_table_init();
    ips_mesh_bridge_init();
    ips_serial_output_start();

    ESP_LOGI(TAG, "Root جاهز - بينتظر heartbeats من الـnodes.");
}
