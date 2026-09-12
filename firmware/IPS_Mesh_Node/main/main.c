// فيرموير الـNode - نفس البورد اللي بيبعت BLE positioning advertising
// (بقى مكتوب بـESP-IDF native / NimBLE، مش Arduino - راجع
// MESH_PROGRESS.md لسبب القرار ده) + مشارك في شبكة الـhealth monitoring
// (mesh_lite) كـnode عادي.
//
// التصميم الكامل: ../../MESH_DESIGN.md
// حالة التنفيذ وTODOs مفتوحة: ../../MESH_PROGRESS.md

#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"

#include "ble_node.h"
#include "config.h"
#include "mesh_participant.h"
#include "node_id_store.h"
#include "provisioning.h"

static const char *TAG = "ips_mesh_node";

static void heartbeat_task(void *arg) {
    (void)arg;
    while (1) {
        mesh_participant_send_heartbeat();
        vTaskDelay(pdMS_TO_TICKS(IPS_HEARTBEAT_INTERVAL_MS));
    }
}

void app_main(void) {
    ESP_LOGI(TAG, "=== IPS Mesh Node starting ===");

    esp_err_t nvs_ret = nvs_flash_init();
    if (nvs_ret == ESP_ERR_NVS_NO_FREE_PAGES || nvs_ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        nvs_ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(nvs_ret);

    node_id_store_init();

    ble_node_start();
    mesh_participant_setup();
    provisioning_task_start();

    xTaskCreate(heartbeat_task, "health_heartbeat", 4096, NULL, 5, NULL);

    ESP_LOGI(TAG, "Node جاهز - BLE advertising شغال + mesh_lite متصل.");
}
