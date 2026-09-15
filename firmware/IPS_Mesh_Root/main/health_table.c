#include "health_table.h"

#include <string.h>
#include "esp_timer.h"

static ips_health_entry_t s_table[IPS_HEALTH_TABLE_MAX_NODES];

void ips_health_table_init(void) {
    memset(s_table, 0, sizeof(s_table));
}

static int find_entry_index(const uint8_t node_id[IPS_NODE_ID_LEN]) {
    for (int i = 0; i < IPS_HEALTH_TABLE_MAX_NODES; i++) {
        if (s_table[i].in_use &&
            memcmp(s_table[i].node_id, node_id, IPS_NODE_ID_LEN) == 0) {
            return i;
        }
    }
    return -1;
}

static int find_free_slot(void) {
    for (int i = 0; i < IPS_HEALTH_TABLE_MAX_NODES; i++) {
        if (!s_table[i].in_use) return i;
    }
    return -1;
}


void ips_health_table_update(const uint8_t node_id[IPS_NODE_ID_LEN],
                              uint8_t hop_count,
                              uint8_t fw_major,
                              uint8_t fw_minor) {
    int idx = find_entry_index(node_id);
    if (idx < 0) {
        idx = find_free_slot();
        if (idx < 0) {
            return;
        }
        memcpy(s_table[idx].node_id, node_id, IPS_NODE_ID_LEN);
        s_table[idx].in_use = true;
    }

    s_table[idx].hop_count   = hop_count;
    s_table[idx].fw_major    = fw_major;
    s_table[idx].fw_minor    = fw_minor;
    s_table[idx].last_seen_us = esp_timer_get_time();
}

void ips_health_table_purge_expired(int64_t max_age_us) {
    int64_t now_us = esp_timer_get_time();
    for (int i = 0; i < IPS_HEALTH_TABLE_MAX_NODES; i++) {
        if (s_table[i].in_use) {
            if ((now_us - s_table[i].last_seen_us) > max_age_us) {
                s_table[i].in_use = false;
            }
        }
    }
}

size_t ips_health_table_count(void) {
    size_t count = 0;
    for (int i = 0; i < IPS_HEALTH_TABLE_MAX_NODES; i++) {
        if (s_table[i].in_use) count++;
    }
    return count;
}

const ips_health_entry_t *ips_health_table_get(size_t index) {
    size_t seen = 0;
    for (int i = 0; i < IPS_HEALTH_TABLE_MAX_NODES; i++) {
        if (!s_table[i].in_use) continue;
        if (seen == index) return &s_table[i];
        seen++;
    }
    return NULL;
}
