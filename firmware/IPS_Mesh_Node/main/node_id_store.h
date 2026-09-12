#pragma once

// تخزين واسترجاع الـnode_id (= esp32_uuid) من NVS. نفس namespace/key
// المستخدمين في الفيرموير الأصلي (Preferences library تحت الغطاء
// بتستخدم NVS برضه) عشان النودز المُجهزة (provisioned) قبل كده تفضل
// شغالة من غير إعادة تجهيز.

#include <stdbool.h>
#include <stdint.h>
#include "config.h"

// الـNode ID الحالي - بيتحمّل في node_id_store_init() وبيتحدّث في
// node_id_store_save().
extern uint8_t g_nodeId[IPS_NODE_ID_LEN];

// بيحمّل node_id من NVS لو موجود، أو يسيب g_nodeId كله أصفار (default،
// = مش provisioned) لو مش موجود. لازم تتنادى مرة واحدة الأول في
// app_main قبل أي استخدام لـg_nodeId.
void node_id_store_init(void);

// بيحفظ node_id جديد في NVS. بترجع true لو نجحت.
bool node_id_store_save(const uint8_t new_id[IPS_NODE_ID_LEN]);

// بيرجع true لو النود متجهزة فعليًا (يعني g_nodeId مش كله أصفار).
bool node_id_store_is_provisioned(void);
