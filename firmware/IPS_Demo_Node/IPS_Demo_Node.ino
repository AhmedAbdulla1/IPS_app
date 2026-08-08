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
#include <string.h> // for memcpy

// ---------------------------------------------------------------------
// Demo node configuration — edit these per physical node.
// ---------------------------------------------------------------------

// Must match BleConstants.manufacturerCompanyId in the Flutter app.
static const uint16_t COMPANY_ID = 0xFFFF;

// 16 raw ID bytes. Matches node_config_seed.dart's demo NodeConfig.
// For additional nodes, change only the last byte (0x02, 0x03, ...).
static const uint8_t NODE_ID_BYTES[16] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04
};

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
static const unsigned long HEARTBEAT_INTERVAL_MS = 2000;

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

/// Builds the 24-byte IPS payload described in the header comment.
void buildPayload(uint8_t *outPayload) {
  size_t offset = 0;

  // Bytes 0-15: Node ID
  memcpy(outPayload + offset, NODE_ID_BYTES, 16);
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

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("=== IPS Demo Node starting ===");

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
  for (int i = 0; i < 16; i++) {
    if (NODE_ID_BYTES[i] < 0x10) Serial.print("0");
    Serial.print(NODE_ID_BYTES[i], HEX);
  }
  Serial.println();
  Serial.println("This must match the nodeId seeded in node_config_seed.dart.");
}

void loop() {
  // Nothing to do here — the advertisement is static and the BLE radio
  // keeps re-transmitting it continuously on its own. We deliberately
  // do NOT call pAdvertising->stop()/start() or rebuild the payload
  // periodically (see updateAdvertisement()'s doc comment for why that
  // caused a heap-corruption crash).
  unsigned long now = millis();
  if (now - lastHeartbeat >= HEARTBEAT_INTERVAL_MS) {
    lastHeartbeat = now;
    Serial.println("Still advertising (static payload, no radio changes needed)...");
  }
}
