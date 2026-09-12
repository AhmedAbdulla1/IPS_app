// فيرموير الـNode - نفس البورد اللي بيبعت BLE positioning advertising
// (منقول من IPS_Demo_Node_v2.0.0.ino زي ما هو) + مشارك دلوقتي في شبكة
// الـhealth monitoring (mesh_lite) كـnode عادي.
//
// كتب كـsketch عادي (setup/loop) لأن المشروع مبني بـ"Arduino as an
// ESP-IDF component" - راجع idf_component.yml.
//
// التصميم الكامل: ../../MESH_DESIGN.md
// حالة التنفيذ وTODOs مفتوحة: ../../MESH_PROGRESS.md

#include <Arduino.h>

#include "ble_node.h"
#include "config.h"
#include "mesh_participant.h"

static unsigned long lastHeartbeatMs = 0;

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("=== IPS Mesh Node starting ===");

  bleNodeSetup();
  meshParticipantSetup();

  Serial.println("Node جاهز - BLE advertising شغال + mesh_lite متصل.");
}

void loop() {
  // provisioning عبر Serial (SET_ID/GET_ID) - نفس المنطق الأصلي.
  bleNodeHandleSerial();

  // heartbeat دوري للـhealth mesh.
  unsigned long now = millis();
  if (now - lastHeartbeatMs >= IPS_HEARTBEAT_INTERVAL_MS) {
    lastHeartbeatMs = now;
    meshParticipantSendHeartbeat();
  }
}
