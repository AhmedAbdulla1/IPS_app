#pragma once

// مشاركة الـnode في شبكة ESP-MESH-LITE (non-root) + إرسال heartbeat
// دوري للـparent/root. التصميم الكامل: ../MESH_DESIGN.md

// بيهيّئ mesh_lite كـnode عادي (مش root). بينادى مرة واحدة من app_main.
void mesh_participant_setup(void);

// بيبعت heartbeat واحدة دلوقتي (تحتوي g_nodeId من node_id_store.h +
// hop count الحالي). بينادى دوريًا من timer في main.c كل
// IPS_HEARTBEAT_INTERVAL_MS.
void mesh_participant_send_heartbeat(void);
