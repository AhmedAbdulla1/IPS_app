#pragma once

// جدول حالة النودز المعروفة عند الـRoot - in-memory بس، مفيش تخزين
// دائم هنا (الـPC هو اللي بيحتفظ بالتاريخ ويرفعه لـSupabase).

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "config.h"

#define IPS_HEALTH_TABLE_MAX_NODES 64

typedef struct {
    uint8_t node_id[IPS_NODE_ID_LEN];
    bool in_use;
    uint8_t hop_count;
    uint8_t fw_major;
    uint8_t fw_minor;
    int64_t last_seen_us; // من esp_timer_get_time()
} ips_health_entry_t;

// بيهيّئ الجدول (لازم يتنادى مرة واحدة في app_main قبل أي استخدام).
void ips_health_table_init(void);

// بيحدّث (أو يضيف) entry لنود معينة. بينادى من الـcallback بتاع استقبال
// heartbeat في mesh_bridge.c.
void ips_health_table_update(const uint8_t node_id[IPS_NODE_ID_LEN],
                              uint8_t hop_count,
                              uint8_t fw_major,
                              uint8_t fw_minor);

// مسح أي نود انتهت مهلتها ولم تعد ترسل heartbeats (مثلاً بعد 15 ثانية)
void ips_health_table_purge_expired(int64_t max_age_us);

// بيرجع عدد الـentries المستخدمة حاليًا في الجدول.
size_t ips_health_table_count(void);

// بيرجع pointer لـentry رقم index (0-based) - بيرجع NULL لو index غير
// صالح. مستخدم في serial_output.c للف على كل النودز.
const ips_health_entry_t *ips_health_table_get(size_t index);
