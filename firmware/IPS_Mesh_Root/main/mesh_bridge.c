#include "mesh_bridge.h"

#include "esp_bridge.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_mesh_lite.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "nvs_flash.h"

#include "health_table.h"

static const char *TAG = "mesh_bridge";

void ips_mesh_bridge_on_heartbeat_received(const uint8_t node_id[IPS_NODE_ID_LEN],
                                            uint8_t hop_count) {
    ips_health_table_update(node_id, hop_count);
}

// -----------------------------------------------------------------------
// TODO (بلوك محتاج تأكيد قبل ما يشتغل فعليًا - راجع MESH_PROGRESS.md):
// -----------------------------------------------------------------------
// دالة استقبال البيانات الخام (raw data) من الـchild nodes مش موثقة
// بتفاصيل كافية في المصادر اللي قدرت أوصلها وقت كتابة الكود ده. الأسماء
// الشائعة في أمثلة mesh_lite بتشمل حاجات زي:
//   esp_mesh_lite_msg_action_list_register(...)
//   esp_mesh_lite_try_add_msg(...)  // للإرسال من child لـroot
// لازم تتأكد من الأسماء والـsignatures الفعلية بالرجوع لـ:
//   - components/mesh_lite/include/esp_mesh_lite.h (بعد ما الـcomponent
//     يتنزل تلقائيًا وقت أول idf.py build)
//   - مثال mesh_local_control في نفس الريبو:
//     https://github.com/espressif/esp-mesh-lite/tree/master/examples/mesh_local_control
//
// لحد ما نتأكد، الدالة ips_mesh_bridge_on_heartbeat_received فوق جاهزة
// تتنادى بمجرد ما نلاقي/نسجل الـcallback الصح.
// -----------------------------------------------------------------------

static void wifi_init(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
}

void ips_mesh_bridge_init(void) {
    ESP_LOGI(TAG, "بيهيّئ mesh bridge (Root role)...");

    wifi_init();

    // بيجهّز netif الجسر بين الـmesh والشبكة المحلية - جزء أساسي من
    // esp-mesh-lite (esp-bridge component).
    esp_bridge_create_all_netif();

    esp_mesh_lite_config_t mesh_lite_config = ESP_MESH_LITE_DEFAULT_INIT();

    // TODO: تأكد من الحقول الصحيحة في esp_mesh_lite_config_t بعد ما
    // الـheader يتنزل - محتاجين نفعّل تحديدًا:
    //   - Root-only (متمنعش الجهاز يشتغل كـchild لو فقد الاتصال بأي راوتر)
    //   - Join/start من غير راوتر (مؤكدة كـfeature عامة من التوثيق، بس
    //     اسم الحقل بالظبط في الـstruct محتاج تأكيد)
    //   - تفعيل AES encryption

    ESP_ERROR_CHECK(esp_mesh_lite_init(&mesh_lite_config));
    ESP_ERROR_CHECK(esp_mesh_lite_start());

    ESP_LOGI(TAG, "mesh_lite اشتغل. الطبقة الحالية: %d",
             esp_mesh_lite_get_level());
}
