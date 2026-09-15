#pragma once

#include <stdint.h>
#include "config.h"

// بيهيّئ ويشغّل ESP-MESH-LITE في وضع Root (بدون راوتر خارجي - القناة
// دي معزولة عن الإنترنت تمامًا زي ما موثق في MESH_DESIGN.md §4.7).
//
// بينادي داخليًا: nvs_flash_init + esp_netif_init + event loop + wifi
// init + esp_bridge_create_all_netif + esp_mesh_lite_init/start.
void ips_mesh_bridge_init(void);

// بينادى من جوه mesh_bridge.c لما heartbeat توصل من أي child node.
// health_table.c هو المسؤول عن التخزين - الدالة دي بس بتوصل البيانات.
void ips_mesh_bridge_on_heartbeat_received(const uint8_t node_id[IPS_NODE_ID_LEN],
                                            uint8_t hop_count,
                                            uint8_t fw_major,
                                            uint8_t fw_minor);
