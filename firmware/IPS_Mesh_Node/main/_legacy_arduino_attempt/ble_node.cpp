// منقول شبه حرفي من IPS_Demo_Node_v2.0.0.ino - نفس المنطق بالظبط
// (buildPayload / updateAdvertisement / provisioning عبر Serial).
// أي تعليقات إنجليزي أصلية اتسابت زي ما هي عشان تفضل موثقة بدقة.

#include "ble_node.h"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <Preferences.h>
#include <string.h>
#include "esp_system.h"

// Must match BleConstants.manufacturerCompanyId in the Flutter app.
static const uint16_t COMPANY_ID = 0xFFFF;

static const uint8_t DEFAULT_NODE_ID_BYTES[16] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

uint8_t g_nodeId[16];

static Preferences prefs;
static const char *PREFS_NAMESPACE = "ips";
static const char *PREFS_KEY_NODE_ID = "node_id";

static const int16_t NODE_X_CM = 1000;
static const int16_t NODE_Y_CM = 600;
static const uint8_t NODE_FLOOR = 0;

static const uint8_t FW_VERSION_MAJOR = 1;
static const uint8_t FW_VERSION_MINOR = 0;

static const uint16_t ADV_INTERVAL_UNITS = 244;

static BLEAdvertising *pAdvertising = nullptr;

static uint8_t readBatteryPercent() {
  return 85; // placeholder — mains-powered demo board
}

static void printResetReason() {
  esp_reset_reason_t reason = esp_reset_reason();
  Serial.print("[RESET REASON] ");
  switch (reason) {
    case ESP_RST_POWERON: Serial.println("POWER ON"); break;
    case ESP_RST_SW: Serial.println("SOFTWARE RESET"); break;
    case ESP_RST_PANIC: Serial.println("PANIC / CRASH"); break;
    case ESP_RST_INT_WDT: Serial.println("INTERRUPT WATCHDOG"); break;
    case ESP_RST_TASK_WDT: Serial.println("TASK WATCHDOG"); break;
    case ESP_RST_WDT: Serial.println("WATCHDOG"); break;
    case ESP_RST_BROWNOUT: Serial.println("BROWNOUT"); break;
    default: Serial.printf("OTHER (%d)\n", reason); break;
  }
}

static void buildPayload(uint8_t *outPayload) {
  size_t offset = 0;
  memcpy(outPayload + offset, g_nodeId, 16);
  offset += 16;
  outPayload[offset++] = (uint8_t)(NODE_X_CM & 0xFF);
  outPayload[offset++] = (uint8_t)((NODE_X_CM >> 8) & 0xFF);
  outPayload[offset++] = (uint8_t)(NODE_Y_CM & 0xFF);
  outPayload[offset++] = (uint8_t)((NODE_Y_CM >> 8) & 0xFF);
  outPayload[offset++] = NODE_FLOOR;
  outPayload[offset++] = readBatteryPercent();
  outPayload[offset++] = FW_VERSION_MAJOR;
  outPayload[offset++] = FW_VERSION_MINOR;
}

static void updateAdvertisement() {
  uint8_t payload[24];
  buildPayload(payload);

  uint8_t fullData[2 + sizeof(payload)];
  fullData[0] = (uint8_t)(COMPANY_ID & 0xFF);
  fullData[1] = (uint8_t)((COMPANY_ID >> 8) & 0xFF);
  memcpy(fullData + 2, payload, sizeof(payload));

  // Binary-safe: explicit length, no strlen() involved (نفس الملاحظة
  // الأصلية - Node ID فيه بايتات 0x00 كتير).
  String manufacturerData(reinterpret_cast<const char *>(fullData), sizeof(fullData));

  BLEAdvertisementData advData;
  advData.setFlags(ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT);
  advData.setManufacturerData(manufacturerData);
  pAdvertising->setAdvertisementData(advData);
  pAdvertising->setScanResponse(false);
}

static bool parseHexNodeId(const String &hex, uint8_t *outBytes) {
  if (hex.length() == 0 || hex.length() > 32) return false;

  String padded = hex;
  while (padded.length() < 32) padded = "0" + padded;

  for (int i = 0; i < 16; i++) {
    char hi = padded[i * 2];
    char lo = padded[i * 2 + 1];
    int hiVal, loVal;

    if (hi >= '0' && hi <= '9') hiVal = hi - '0';
    else if (hi >= 'a' && hi <= 'f') hiVal = hi - 'a' + 10;
    else if (hi >= 'A' && hi <= 'F') hiVal = hi - 'A' + 10;
    else return false;

    if (lo >= '0' && lo <= '9') loVal = lo - '0';
    else if (lo >= 'a' && lo <= 'f') loVal = lo - 'a' + 10;
    else if (lo >= 'A' && lo <= 'F') loVal = lo - 'A' + 10;
    else return false;

    outBytes[i] = (uint8_t)((hiVal << 4) | loVal);
  }
  return true;
}

static void printNodeId(const uint8_t *idBytes) {
  for (int i = 0; i < 16; i++) {
    if (idBytes[i] < 0x10) Serial.print("0");
    Serial.print(idBytes[i], HEX);
  }
  Serial.println();
}

static void loadNodeIdFromNvs() {
  prefs.begin(PREFS_NAMESPACE, /*readOnly=*/false);

  size_t storedLen = prefs.getBytesLength(PREFS_KEY_NODE_ID);
  if (storedLen == 16) {
    prefs.getBytes(PREFS_KEY_NODE_ID, g_nodeId, 16);
    Serial.print("[PROVISION] Loaded Node ID from NVS: ");
    printNodeId(g_nodeId);
  } else {
    memcpy(g_nodeId, DEFAULT_NODE_ID_BYTES, 16);
    Serial.println("[PROVISION] \xE2\x9A\xA0 NOT PROVISIONED \xE2\x80\x94 no Node ID in NVS, using default (all zeros).");
    Serial.println("[PROVISION] Send 'SET_ID:<hex>' over Serial to provision this node.");
  }

  prefs.end();
}

static void handleSerialCommand(const String &line) {
  String cmd = line;
  cmd.trim();
  if (cmd.length() == 0) return;

  if (cmd.equalsIgnoreCase("GET_ID")) {
    Serial.print("[PROVISION] Current Node ID: ");
    printNodeId(g_nodeId);
    return;
  }

  if (cmd.startsWith("SET_ID:") || cmd.startsWith("set_id:")) {
    String hexPart = cmd.substring(7);
    uint8_t newId[16];

    if (!parseHexNodeId(hexPart, newId)) {
      Serial.println("[PROVISION] ERROR: invalid hex value. Use 1-32 hex chars, e.g. SET_ID:4 or SET_ID:3e8");
      return;
    }

    prefs.begin(PREFS_NAMESPACE, /*readOnly=*/false);
    prefs.putBytes(PREFS_KEY_NODE_ID, newId, 16);
    prefs.end();

    Serial.print("[PROVISION] New Node ID saved to NVS: ");
    printNodeId(newId);
    Serial.println("[PROVISION] Rebooting to apply...");
    Serial.flush();
    delay(100);
    ESP.restart();
    return;
  }

  Serial.println("[PROVISION] Unknown command. Supported: SET_ID:<hex>, GET_ID");
}

void bleNodeSetup() {
  printResetReason();
  loadNodeIdFromNvs();

  BLEDevice::init("IPS-Node");

  pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->setAdvertisementType(ADV_TYPE_NONCONN_IND);
  pAdvertising->setMinInterval(ADV_INTERVAL_UNITS);
  pAdvertising->setMaxInterval(ADV_INTERVAL_UNITS);

  updateAdvertisement();
  pAdvertising->start();

  Serial.println("Advertising started.");
  Serial.print("Company ID: 0x");
  Serial.println(COMPANY_ID, HEX);
  Serial.print("Node ID (hex): ");
  printNodeId(g_nodeId);
  Serial.println("Send 'SET_ID:<hex>' over Serial at any time to re-provision this node.");
}

void bleNodeHandleSerial() {
  if (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    handleSerialCommand(line);
  }
}
