#pragma once

// كود الـBLE advertising + provisioning - منقول شبه حرفي من
// IPS_Demo_Node_v2.0.0.ino (نفس المنطق بالظبط)، بس متغلف كدوال بدل ما
// يكون setup()/loop() مباشرة، عشان main.cpp ينسّق بينه وبين mesh_participant.
//
// تصحيح بالنسبة لملاحظة قلتها غلط قبل كده: راجعت الملف الأصلي تاني
// ولقيت إن loadNodeIdFromNvs() فعليًا بتتنادى في setup() ومش متعلقة -
// عكس اللي قلته. آسف على اللخبطة. الكود هنا منقول زي ما هو من غير أي
// تعديل على السلوك ده.

#include <stdint.h>

// الـNode ID الفعلي (= esp32_uuid) - بيتحمّل من NVS في bleNodeSetup().
// mesh_participant.cpp بيستخدمها كـnode_id في heartbeat.
extern uint8_t g_nodeId[16];

// بيهيّئ BLE advertising + provisioning (NVS load). بينادى مرة واحدة من
// setup() في main.cpp.
void bleNodeSetup();

// بيتعامل مع أوامر Serial (SET_ID/GET_ID). بينادى كل loop() iteration.
void bleNodeHandleSerial();
