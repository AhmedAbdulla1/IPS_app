#pragma once

// BLE advertising بـESP-IDF native (NimBLE) - نفس منطق ونفس صيغة الـ
// payload بتاعة IPS_Demo_Node_v2.0.0.ino الأصلية، بس بدون Arduino.

// بيهيّئ NimBLE ويبدأ الإعلان (advertising). لازم node_id_store_init()
// يتنادى قبلها عشان g_nodeId يبقى جاهز وقت بناء أول payload.
void ble_node_start(void);

// بيعيد بناء وتحديث بيانات الإعلان (يتنادى بعد أي تغيير في g_nodeId،
// زي إعادة التجهيز عبر SET_ID).
void ble_node_refresh_advertisement(void);
