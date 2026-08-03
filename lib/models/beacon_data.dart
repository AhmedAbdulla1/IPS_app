import 'dart:convert';

class BeaconData {
  String name;
  String uuid;
  String macAddress;
  String major;
  String minor;
  String distance;
  String proximity;
  String scanTime;
  String rssi;
  String txPower;
  DateTime dateTime;

  BeaconData({
    required this.name,
    required this.uuid,
    required this.macAddress,
    required this.major,
    required this.minor,
    required this.distance,
    required this.proximity,
    required this.scanTime,
    required this.rssi,
    required this.txPower,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'uuid': uuid,
      'macAddress': macAddress,
      'major': major,
      'minor': minor,
      'distance': distance,
      'proximity': proximity,
      'scanTime': scanTime,
      'rssi': rssi,
      'txPower': txPower,
      'dateTime': dateTime.millisecondsSinceEpoch,
    };
  }

  factory BeaconData.fromMap(Map<String, dynamic> map) {
    return BeaconData(
      name: map['name'] ?? '',
      uuid: map['uuid'] ?? '',
      macAddress: map['macAddress'] ?? '',
      major: map['major']?.toString() ?? '',
      minor: map['minor']?.toString() ?? '',
      distance: map['distance']?.toString() ?? '',
      proximity: map['proximity']?.toString() ?? '',
      scanTime: map['scanTime']?.toString() ?? '',
      rssi: map['rssi']?.toString() ?? '',
      txPower: map['txPower']?.toString() ?? '',
      dateTime: DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory BeaconData.fromJson(String source) =>
      BeaconData.fromMap(json.decode(source));
}
