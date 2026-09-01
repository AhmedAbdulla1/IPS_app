/*
 * IPS_Demo_Node.ino
 * ---------------------------------------------------------------------
 * Minimal ESP32 firmware for the Indoor Positioning System (IPS) MVP
 * demo (IPS_MVP_Roadmap_V1.md, Commit 9-11 manual verification).
 *
 * Broadcasts a non-connectable BLE advertisement containing manufacturer
 * data that the app's current `BleNodeAdvertisementModel.tryDecode()`
 * can parse (see lib/core/constants/ble_constants.dart for the
 * authoritative wire-format doc comment).
 *
 * IMPORTANT: this firmware intentionally matches the app's CURRENT
 * (already-implemented) decoder, NOT the richer future wire format
 * described in IPS_BLE_Advertisement_Protocol_V1.md. That document is a
 * draft spec for a later migration (see its own §21) and has not been
 * implemented in the Flutter code yet — broadcasting that format today
 * would not be parsed by the app at all.
 *
 * On-air structure (what a sniffer sees):
 *   [Flags AD]  [Manufacturer Specific Data AD: Company ID (2 bytes,
 *   0xFFFF) + 24-byte IPS payload]
 *
 * The 24-byte IPS payload (this is what flutter_blue_plus hands back to
 * the app AFTER it strips the 2-byte company ID):
 *   Offset  Size  Field
 *   0-15    16    Node ID (raw bytes, hex-encoded by the app)
 *   16-17   2     X coordinate, int16 LE, centimeters
 *   18-19   2     Y coordinate, int16 LE, centimeters
 *   20      1     Floor, uint8
 *   21      1     Battery %, uint8 (0xFF = not reported)
 *   22      1     Firmware version major
 *   23      1     Firmware version minor
 *
 * ---------------------------------------------------------------------
 * SETUP INSTRUCTIONS
 * ---------------------------------------------------------------------
 * 1. Arduino IDE -> Tools -> Board -> install "esp32" by Espressif
 *    Systems (Boards Manager) if you haven't already.
 * 2. Select your board (e.g. "ESP32 Dev Module").
 * 3. No extra libraries to install — BLEDevice/BLEAdvertising ship with
 *    the ESP32 Arduino core.
 * 4. Flash this file to your ESP32.
 * 5. Open Serial Monitor at 115200 baud to see advertisement counts.
 *
 * The NODE_ID_BYTES below deliberately match the demo seed already
 * written into the Flutter app's Hive node-config box by
 * lib/core/di/node_config_seed.dart (all zero bytes except the last,
 * which is 0x01). This means: flash this firmware as-is, and the app
 * should resolve a position with ZERO additional configuration on
 * either side. If you add more physical nodes later, give each one a
 * different last byte (0x02, 0x03, ...) and add a matching NodeConfig
 * entry in node_config_seed.dart.
 * ---------------------------------------------------------------------
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <Preferences.h>
#include <string.h> // for memcpy
#include "esp_system.h"
// ---------------------------------------------------------------------
// Demo node configuration — edit these per physical node.
// ---------------------------------------------------------------------

// Must match BleConstants.manufacturerCompanyId in the Flutter app.
static const uint16_t COMPANY_ID = 0xFFFF;

// Node ID الافتراضي، بيتستخدم بس في أول تشغيل للشريحة قبل أي provisioning
// عبر Serial (SET_ID). بعد أول SET_ID، القيمة دي معادش بتتستخدم تاني.
static const uint8_t DEFAULT_NODE_ID_BYTES[16] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

// الـ Node ID الفعلي اللي بيتبث. بيتحمّل من NVS في setup().
static uint8_t g_nodeId[16];

Preferences prefs;
static const char *PREFS_NAMESPACE = "ips";
static const char *PREFS_KEY_NODE_ID = "node_id";

// Static physical position of this node, in centimeters.
// Matches node_config_seed.dart's demo NodeConfig (x: 1000, y: 600).
// NOTE: the app does not currently read X/Y/floor from the
// advertisement itself (see BleNodeAdvertisementModel's doc comment) —
// it looks these up from the seeded NodeConfig by nodeId instead. These
// fields are broadcast anyway for wire-format completeness / future use.
static const int16_t NODE_X_CM = 1000;
static const int16_t NODE_Y_CM = 600;
static const uint8_t NODE_FLOOR = 0;

// Firmware version reported in the advertisement (major.minor).
static const uint8_t FW_VERSION_MAJOR = 1;
static const uint8_t FW_VERSION_MINOR = 0;

// How often to print a Serial heartbeat so you can confirm the node
// is still alive. Does NOT rebuild or touch the advertisement itself —
// the payload is static and built exactly once in setup() (see
// updateAdvertisement()'s doc comment for why repeatedly
// stopping/restarting the advertiser was removed).
// static const unsigned long HEARTBEAT_INTERVAL_MS = 2000;

// BLE advertising interval (see IPS_BLE_Advertisement_Protocol_V1.md
// §15 for the rationale: 100-250ms range, default ~152.5ms). Units here
// are in 0.625ms steps, so 152.5ms / 0.625ms = 244.
static const uint16_t ADV_INTERVAL_UNITS = 244;

// ---------------------------------------------------------------------

BLEAdvertising *pAdvertising = nullptr;
unsigned long lastHeartbeat = 0;

/// Reads (or simulates) the current battery percentage.
/// Replace this with a real ADC/fuel-gauge reading before production —
/// this demo firmware just reports a fixed value.
uint8_t readBatteryPercent() {
  return 85; // placeholder — mains-powered demo board
}


void printResetReason()
{
    esp_reset_reason_t reason = esp_reset_reason();

    Serial.print("[RESET REASON] ");

    switch (reason)
    {
        case ESP_RST_POWERON:
            Serial.println("POWER ON");
            break;

        case ESP_RST_SW:
            Serial.println("SOFTWARE RESET");
            break;

        case ESP_RST_PANIC:
            Serial.println("PANIC / CRASH");
            break;

        case ESP_RST_INT_WDT:
            Serial.println("INTERRUPT WATCHDOG");
            break;

        case ESP_RST_TASK_WDT:
            Serial.println("TASK WATCHDOG");
            break;

        case ESP_RST_WDT:
            Serial.println("WATCHDOG");
            break;

        case ESP_RST_BROWNOUT:
            Serial.println("BROWNOUT");
            break;

        default:
            Serial.printf("OTHER (%d)\n", reason);
            break;
    }
}

/// Builds the 24-byte IPS payload described in the header comment.
void buildPayload(uint8_t *outPayload) {
  size_t offset = 0;

  // Bytes 0-15: Node ID
  memcpy(outPayload + offset, g_nodeId, 16);
  offset += 16;

  // Bytes 16-17: X coordinate (int16, little-endian)
  outPayload[offset++] = (uint8_t)(NODE_X_CM & 0xFF);
  outPayload[offset++] = (uint8_t)((NODE_X_CM >> 8) & 0xFF);

  // Bytes 18-19: Y coordinate (int16, little-endian)
  outPayload[offset++] = (uint8_t)(NODE_Y_CM & 0xFF);
  outPayload[offset++] = (uint8_t)((NODE_Y_CM >> 8) & 0xFF);

  // Byte 20: Floor
  outPayload[offset++] = NODE_FLOOR;

  // Byte 21: Battery %
  outPayload[offset++] = readBatteryPercent();

  // Bytes 22-23: Firmware version (major.minor)
  outPayload[offset++] = FW_VERSION_MAJOR;
  outPayload[offset++] = FW_VERSION_MINOR;
}

/// Builds the advertisement data ONCE and pushes it to the BLE stack.
/// Advertising-only, non-connectable — no GATT service, no
/// characteristic, no scan response, matching the architecture's
/// "advertisement-only, no BLE connections during positioning" rule.
///
/// IMPORTANT (heap-corruption fix): this used to be called repeatedly
/// from loop() followed by pAdvertising->stop()/start() to "refresh"
/// the payload. On the classic ESP32 Bluedroid BLE stack, rapidly
/// cycling stop()/start() while rebuilding BLEAdvertisementData
/// corrupts the heap (`CORRUPT HEAP: Bad head at ...`, then a reboot
/// loop). Since none of this demo's fields (battery/position/floor)
/// actually change at runtime, the fix is simply: build the payload
/// once in setup(), call start() once, and never touch the advertiser
/// again during normal operation. The BLE radio keeps re-transmitting
/// the same advertisement continuously on its own — nothing needs to
/// be "refreshed" from the application side.
///
/// IMPORTANT (binary-safety): this data is NOT a null-terminated C
/// string — the Node ID is mostly 0x00 bytes.
/// `BLEAdvertisementData::setManufacturerData` on this ESP32 core
/// version (3.3.0) takes an Arduino `String`, not `std::string` — so
/// we use `String`'s explicit-length constructor
/// `String(const char*, unsigned int)`, which is binary-safe (copies
/// exactly `length` bytes via memcpy). Do NOT use `String(const char*)`
/// (no length), `+=` with a C-string, or `.concat(const char*)`
/// without a length — all of those call strlen() internally and would
/// stop at the first embedded 0x00, silently truncating the payload.
void updateAdvertisement() {
  uint8_t payload[24];
  buildPayload(payload);

  // Manufacturer Specific Data AD structure content = Company ID (2
  // bytes, little-endian) + the 24-byte payload above, built as one
  // contiguous raw byte buffer first.
  uint8_t fullData[2 + sizeof(payload)];
  fullData[0] = (uint8_t)(COMPANY_ID & 0xFF);
  fullData[1] = (uint8_t)((COMPANY_ID >> 8) & 0xFF);
  memcpy(fullData + 2, payload, sizeof(payload));

  // Binary-safe: explicit length, no strlen() involved.
  String manufacturerData(reinterpret_cast<const char *>(fullData), sizeof(fullData));

  BLEAdvertisementData advData;
  
  advData.setFlags(ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT);

  advData.setManufacturerData(manufacturerData);

  pAdvertising->setAdvertisementData(advData);

  // No scan response used — the protocol places every field the app
  // needs in the primary advertisement (passive scanning only).
  // BLEAdvertisementData scanResponseData;
  // pAdvertising->setScanResponseData(scanResponseData);
  pAdvertising->setScanResponse(false);
}

/// بيحوّل نص hex (زي "4" أو "000...03e8") إلى 16 بايت خام في outBytes.
/// بيقبل من 1 لحد 32 حرف hex، وبيعمل left-pad بالأصفار لحد 32 حرف.
/// بيرجع false لو فيه حرف مش hex صحيح أو الطول أكتر من 32.
bool parseHexNodeId(const String &hex, uint8_t *outBytes) {
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

/// بيطبع الـ Node ID بصيغة hex على الـ Serial.
void printNodeId(const uint8_t *idBytes) {
  for (int i = 0; i < 16; i++) {
    if (idBytes[i] < 0x10) Serial.print("0");
    Serial.print(idBytes[i], HEX);
  }
  Serial.println();
}

/// بيحمّل الـ Node ID من NVS. لو مفيش ID متخزن قبل كده (أول تشغيل للشريحة
/// دي)، بيستخدم DEFAULT_NODE_ID_BYTES وبيطبع تحذير إن الجهاز لسه مش
/// provisioned.
void loadNodeIdFromNvs() {
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

/// بيتعامل مع أوامر الـ Serial. الأوامر المدعومة:
///   SET_ID:<hex>   يكتب Node ID جديد في NVS ويعمل reboot نضيف.
///   GET_ID         يطبع الـ Node ID الحالي من غير أي تعديل.
///
/// بعد كتابة ID جديد بنعمل ESP.restart() بدل ما نلمس
/// pAdvertising->stop()/start() مباشرة، عشان نتجنب مشكلة الـ heap
/// corruption الموثقة في تعليقات updateAdvertisement() فوق.
void handleSerialCommand(const String &line) {
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

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("=== IPS Demo Node starting ===");

  printResetReason();
  // loadNodeIdFromNvs();
 
  BLEDevice::init("IPS-Node");
  

  pAdvertising = BLEDevice::getAdvertising();

  // Non-connectable advertising — this node is a passive beacon only.
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

void loop() {
  // الإعلان (advertisement) نفسه ثابت وبيتبث تلقائيًا من الراديو — إحنا
  // مش بنلمسه هنا زي الأول. الإضافة الوحيدة هنا هي قراءة أوامر
  // provisioning الجاية عبر Serial (SET_ID / GET_ID).
  if (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    handleSerialCommand(line);
  }

  // unsigned long now = millis();
  // if (now - lastHeartbeat >= HEARTBEAT_INTERVAL_MS) {
  //   lastHeartbeat = now;
  //   Serial.println("Still advertising (static payload, no radio changes needed)...");
  // }
}
