#pragma once

// توزيع الفيرموير الجديد على الـNodes عبر الـmesh - المرحلة اللي بعد
// ما الـRoot يستقبل وينفلاش بنفسه (راجع ota_receiver.c). بيستخدم
// esp_mesh_lite_transmit_file_start + provide_file_cb (المكتبة نفسها
// اللي IPS_Mesh_Node/main/ota_apply.c بيستناها في الطرف التاني عبر
// get_file_cb/get_file_done).

/**
 * لازم تتنادى مرة واحدة في app_main، بعد ips_mesh_bridge_init() (محتاج
 * mesh_lite يكون بدأ فعلاً) وبعد nvs_flash_init (بيتعمل جوه
 * mesh_bridge_init). بتفحص NVS - لو فيه فيرموير اتسجل إنه "لسه محتاج
 * يتوزّع" (من جلسة OTA سابقة قبل آخر reboot)، بتبدأ التوزيع تلقائيًا.
 */
#include <stdint.h>
#include "esp_err.h"

void ips_ota_relay_init(void);

/**
 * @brief بدء توزيع فيرموير الـNode عبر شبكة الـMesh فوراً بعد اكتمال استلامه من السيريال
 */
esp_err_t ips_ota_relay_start(uint32_t size, const char *version);

/**
 * @brief إعادة توزيع الفيرموير المحفوظ في الفلاش دون الحاجة لإعادة رفعه عبر السيريال
 */
esp_err_t ips_ota_relay_redistribute(void);
