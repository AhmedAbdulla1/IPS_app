/*
 * ESP32 iBeacon Node Firmware - Pathfinder Indoor Navigation System
 * ----------------------------------------------------------------
 * This firmware turns an ESP32 microcontroller into a BLE iBeacon Node.
 * It periodically broadcasts its UUID, Major, Minor, and Measured Power (TxPower)
 * so nearby mobile devices running the Pathfinder app can calculate proximity
 * and pinpoint decision points inside buildings.
 *
 * Requirements:
 * - ESP32 Development Board (ESP32-WROOM, ESP32-S3, etc.)
 * - Arduino IDE with ESP32 board support installed (version 2.x or 3.x)
 * - Select board: "ESP32 Dev Module"
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>

// =========================================================================
// NODE CONFIGURATION
// Customize these parameters for each ESP32 node deployed in the building!
// =========================================================================
#define NODE_ID "POI_NODE_1"

// UUID string format: 8-4-4-4-12 hex characters
// Example UUIDs matching Pathfinder POINodes in Flutter:
// Node 1:  1510eae0-be73-451f-8faf-6b622f92ac5f
// Node 2:  5f0868e1-a25a-4213-8d81-66d2517fa79e
// Node 3:  91551886-569b-4993-aa64-1ae9739a46b4
// Node 4:  89206b21-ec85-4487-a051-c20819b40833
// Node 5:  9f3442b9-5672-4501-9459-c74d7ce4e5dd
#define BEACON_UUID "1510eae0-be73-451f-8faf-6b622f92ac5f"

// Major: Building / Floor identifier (e.g., Floor 1 = 1)
#define BEACON_MAJOR 1

// Minor: Specific landmark or node number (e.g., Node 1 = 1)
#define BEACON_MINOR 1

// Measured Power (RSSI at 1 meter distance, usually -59 dBm)
#define BEACON_TX_POWER -59

// Advertising Interval (in units of 0.625 ms: 160 * 0.625ms = 100ms interval for fast discovery)
#define ADV_INTERVAL_MIN 0x00A0
#define ADV_INTERVAL_MAX 0x00A0

BLEAdvertising *pAdvertising;

// Helper to convert formatted UUID string to 16-byte array
void parseUUIDHex(const char* uuidStr, uint8_t* outBytes) {
  int outIdx = 0;
  for (int i = 0; uuidStr[i] != '\0' && outIdx < 16; i++) {
    if (uuidStr[i] == '-') continue;
    char hex[3] = { uuidStr[i], uuidStr[i+1], '\0' };
    outBytes[outIdx++] = (uint8_t) strtol(hex, NULL, 16);
    i++;
  }
}

void setBeacon() {
  BLEAdvertisementData oAdvertisementData;
  
  // Set BLE Flags: General Discoverable + BR_EDR_NOT_SUPPORTED (0x06)
  oAdvertisementData.setFlags(0x06);

  // Construct 25-byte Manufacturer Specific Data payload for iBeacon:
  // Byte 0..1  : 0x4C, 0x00 (Apple Company Identifier)
  // Byte 2..3  : 0x02, 0x15 (iBeacon Subtype & Length = 21)
  // Byte 4..19 : 16-byte UUID
  // Byte 20..21: 2-byte Major
  // Byte 22..23: 2-byte Minor
  // Byte 24    : 1-byte TxPower
  uint8_t mfgData[25];
  mfgData[0] = 0x4C; // Apple Company ID LSB
  mfgData[1] = 0x00; // Apple Company ID MSB
  mfgData[2] = 0x02; // iBeacon Subtype
  mfgData[3] = 0x15; // Subtype Length (21 bytes)

  // 16-byte Proximity UUID
  parseUUIDHex(BEACON_UUID, &mfgData[4]);

  // Major (2 bytes big endian)
  mfgData[20] = (uint8_t)((BEACON_MAJOR >> 8) & 0xFF);
  mfgData[21] = (uint8_t)(BEACON_MAJOR & 0xFF);

  // Minor (2 bytes big endian)
  mfgData[22] = (uint8_t)((BEACON_MINOR >> 8) & 0xFF);
  mfgData[23] = (uint8_t)(BEACON_MINOR & 0xFF);

  // Measured Power (1 byte signed int8)
  mfgData[24] = (uint8_t)BEACON_TX_POWER;

  // Pass Manufacturer Data directly to AdvertisementData
  oAdvertisementData.setManufacturerData(String((char*)mfgData, 25));

  pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->setAdvertisementData(oAdvertisementData);
  pAdvertising->setMinInterval(ADV_INTERVAL_MIN);
  pAdvertising->setMaxInterval(ADV_INTERVAL_MAX);
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("==================================================");
  Serial.println(" Pathfinder INS - ESP32 iBeacon Node Firmware ");
  Serial.println("==================================================");
  Serial.printf("Node Name: %s\n", NODE_ID);
  Serial.printf("UUID     : %s\n", BEACON_UUID);
  Serial.printf("Major    : %d\n", BEACON_MAJOR);
  Serial.printf("Minor    : %d\n", BEACON_MINOR);
  Serial.printf("TxPower  : %d dBm\n", BEACON_TX_POWER);
  Serial.println("--------------------------------------------------");

  BLEDevice::init(NODE_ID);

  setBeacon();

  // Start advertising
  pAdvertising->start();
  Serial.println("✓ iBeacon Advertising Started Successfully!");
  Serial.println("Device is now broadcasting to Pathfinder app...");
}

void loop() {
  delay(5000);
  Serial.printf("[%lums] Node %s actively broadcasting iBeacon...\n", millis(), NODE_ID);
}
