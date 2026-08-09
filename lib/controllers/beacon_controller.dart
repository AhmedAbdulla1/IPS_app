import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:pathfinder/models/beacon_data.dart';
import 'package:pathfinder/models/location.dart';
import 'package:pathfinder/models/neighbour_node.dart';
import 'package:pathfinder/models/poinode.dart';
import 'package:pathfinder/utils/constants.dart';
import 'package:permission_handler/permission_handler.dart';

import 'navigation_controller.dart';

class BeaconController extends GetxController {
  var poiNodes = <int, POINode>{};
  var poiList = List<POINode>.empty();
  var locationList = List<LocationInfo>.empty();
  final currentLocation = POINode(
    level: 0,
    name: '',
    nearestLift: 0,
    neighbourArray: [],
    nodeESP32ID: '',
    nodeID: 0,
    nodeName: '',
    poiType: POIType.poi,
    section: '',
    x: 0,
    y: 0,
  ).obs;
  var fetchingBeacons = true.obs;
  var haveCurrentLocation = false.obs;
  var beaconResult = ''.obs;
  int beaconRssiCutoff = -80;
  Timer? _timer;
  int _timerTime = 0;
  Timer? _scanRestartTimer; // تايمر لإعادة تشغيل السكان تلقائيًا لو انتهى

  POINode? destinationLocation;

  // Shared instance registered once in main.dart
  final FlutterReactiveBle _ble = Get.find<FlutterReactiveBle>();

  // Stream subscription for BLE device scanning
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  bool _isRanging = false;

  Comparator<BeaconData> rssiComparator = (a, b) => int.parse(b.rssi).compareTo(int.parse(a.rssi));
  final beaconDataPriorityQueue = List<BeaconData>.empty().obs;

  @override
  void onInit() {
    super.onInit();
    fetchLocationInfo();
    fetchPoiNodes();
  }

  @override
  void dispose() {
    print('Disposing Controller');
    _timer?.cancel();
    _scanRestartTimer?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }

  void setDestination(int nodeID) {
    destinationLocation =
        poiList.firstWhere((element) => element.nodeID == nodeID);
  }

  Future<List<LocationInfo>> onSearch(String filter) async {
    return locationList
        .where((element) =>
            element.nodeID != currentLocation.value.nodeID &&
            element.name.contains(filter))
        .toList();
  }

  void startTimer(int timeSet) {
    const oneSec = Duration(seconds: 1);
    _timerTime = timeSet;
    _timer = Timer.periodic(oneSec, (Timer timer) {
      print('object');
      if (_timerTime < 1) {
        timer.cancel();
        _timer = null;
        fetchingBeacons.value = false;
        haveCurrentLocation.value = false;
        print("Not nearby beacon");
      } else {
        _timerTime = _timerTime - 1;
      }
    });
  }

  void cancelTimer() {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> beaconInitPlatformState() async {
    if (_isRanging) return;

    print('[BEACON] Starting BLE scan for ESP32 iBeacon nodes via flutter_reactive_ble');

    startTimer(5);
    _isRanging = true;

    _scanSubscription = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen(
      (DiscoveredDevice device) {
        if (device.manufacturerData.isNotEmpty) {
           print('[DEBUG] Found Device ID: ${device.id}. Name: "${device.name}". Bytes length: ${device.manufacturerData.length}. Data: ${device.manufacturerData}');
        }
        
        final beaconData = _parseIBeacon(device);
        if (beaconData != null) {
          print(
              '[BEACON] 📍 Beacon detected: UUID=${beaconData.uuid}, Major=${beaconData.major}, Minor=${beaconData.minor}, RSSI=${beaconData.rssi}');

          fetchingBeacons.value = false;
          cancelTimer();
          addToListAndSort(beaconData);
        }
      },
      onDone: () {
        // الـ stream انتهت (بعض الأجهزة/الأنظمة بتوقف السكان تلقائيًا)
        // → نعيد تشغيله بعد ثانية واحدة قصيرة
        print('[BEACON] Scan stream ended (onDone) — scheduling restart in 1s');
        _isRanging = false;
        _scheduleRestart();
      },
      onError: (error) {
        // خطأ في الـ stream → نعيد المحاولة بعد 3 ثواني لتفادي loop سريعة
        print('[BEACON] Scan stream error: $error — scheduling restart in 3s');
        _isRanging = false;
        _scheduleRestart(delaySeconds: 3);
      },
    );
  }

  /// يُجدوِل إعادة تشغيل السكان بعد تأخير معيّن.
  /// يُلغي أي جدولة سابقة قبل إنشاء جديدة.
  void _scheduleRestart({int delaySeconds = 1}) {
    _scanRestartTimer?.cancel();
    _scanRestartTimer = Timer(Duration(seconds: delaySeconds), () {
      _scanRestartTimer = null;
      print('[BEACON] Auto-restarting BLE scan...');
      beaconInitPlatformState();
    });
  }

  BeaconData? _parseIBeacon(DiscoveredDevice device) {
    final bytes = device.manufacturerData;
    
    // 1. Check for the NEW IPS Custom Protocol (0xFFFF Company ID)
    if (bytes.length >= 26 && bytes[0] == 0xFF && bytes[1] == 0xFF) {
      final uuidBytes = bytes.sublist(2, 18);
      final rawHex = uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final formattedUuid = '${rawHex.substring(0, 8)}-${rawHex.substring(8, 12)}-${rawHex.substring(12, 16)}-${rawHex.substring(16, 20)}-${rawHex.substring(20, 32)}'.toLowerCase();
      
      final major = (bytes[19] << 8) | bytes[18]; // X coord
      final minor = (bytes[21] << 8) | bytes[20]; // Y coord
      final txPower = -59; // Hardcoded default for distance calc

      final double distance = _calculateDistance(txPower, device.rssi);
      final String proximityStr = _getProximity(distance);

      return BeaconData(
        name: device.name.isNotEmpty ? device.name : formattedUuid,
        uuid: formattedUuid, // This will be 00000000-0000-0000-0000-000000000001
        macAddress: device.id,
        major: major.toString(),
        minor: minor.toString(),
        distance: distance.toStringAsFixed(2),
        proximity: proximityStr,
        scanTime: DateTime.now().millisecondsSinceEpoch.toString(),
        rssi: device.rssi.toString(),
        txPower: txPower.toString(),
        dateTime: DateTime.now(),
      );
    }

    // 2. Existing Apple iBeacon fallback parsing...
    if (bytes.length < 23) return null;

    int offset = -1;

    // Search for Apple iBeacon header (0x004C company ID, 0x02 subtype, 0x15 length)
    for (int i = 0; i <= bytes.length - 23; i++) {
      if (i + 24 <= bytes.length &&
          bytes[i] == 0x4C &&
          bytes[i + 1] == 0x00 &&
          bytes[i + 2] == 0x02 &&
          bytes[i + 3] == 0x15) {
        offset = i + 4;
        break;
      } else if (bytes[i] == 0x02 && bytes[i + 1] == 0x15) {
        offset = i + 2;
        break;
      }
    }

    if (offset == -1 || bytes.length < offset + 21) {
      return null;
    }

    final uuidBytes = bytes.sublist(offset, offset + 16);
    final rawHex =
        uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final formattedUuid =
        '${rawHex.substring(0, 8)}-${rawHex.substring(8, 12)}-${rawHex.substring(12, 16)}-${rawHex.substring(16, 20)}-${rawHex.substring(20, 32)}'
            .toLowerCase();

    final major = (bytes[offset + 16] << 8) | bytes[offset + 17];
    final minor = (bytes[offset + 18] << 8) | bytes[offset + 19];
    final txPower = bytes[offset + 20].toSigned(8);

    final double distance = _calculateDistance(txPower, device.rssi);
    final String proximityStr = _getProximity(distance);

    return BeaconData(
      name: device.name.isNotEmpty ? device.name : formattedUuid,
      uuid: formattedUuid,
      macAddress: device.id,
      major: major.toString(),
      minor: minor.toString(),
      distance: distance.toStringAsFixed(2),
      proximity: proximityStr,
      scanTime: DateTime.now().millisecondsSinceEpoch.toString(),
      rssi: device.rssi.toString(),
      txPower: txPower.toString(),
      dateTime: DateTime.now(),
    );
  }

  double _calculateDistance(int txPower, int rssi) {
    if (rssi == 0) return -1.0;
    double ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return math.pow(ratio, 10).toDouble();
    } else {
      return (0.89976) * math.pow(ratio, 7.7095) + 0.111;
    }
  }

  String _getProximity(double distance) {
    if (distance < 0) return 'unknown';
    if (distance < 0.5) return 'immediate';
    if (distance < 3.0) return 'near';
    return 'far';
  }

  Future<void> startMonitoring() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (statuses[Permission.location]!.isGranted || statuses[Permission.bluetoothScan]!.isGranted) {
      await beaconInitPlatformState();
    } else {
      print("[BEACON] Permissions not granted!");
    }
  }

  void addToListAndSort(BeaconData beaconData) {
    var beaconIndexInList = poiList.indexWhere(
        (beacon) => beacon.nodeESP32ID.toLowerCase() == beaconData.uuid.toLowerCase());

    if (beaconIndexInList != -1) {
      print("Index: $beaconIndexInList");
      var beaconIndexInQueue = beaconDataPriorityQueue.indexWhere(
          (beacon) => beacon.uuid.toLowerCase() == beaconData.uuid.toLowerCase());

      if (beaconIndexInQueue == -1)
        beaconDataPriorityQueue.add(beaconData);
      else {
        beaconDataPriorityQueue[beaconIndexInQueue] = beaconData;
      }

      beaconDataPriorityQueue.removeWhere((item) {
        var diff = DateTime.now().difference(item.dateTime);
        // نمنح الـ beacon 8 ثواني قبل إزالته — يكفي فترات الـ scan الطبيعية
        if (diff.inSeconds >= 8) return true;
        return false;
      });

      beaconDataPriorityQueue.sort(rssiComparator);
      var tempString = '';
      for (var item in beaconDataPriorityQueue) {
        tempString += item.name + " : " + item.rssi + '\n';
      }
      beaconResult.value = tempString;
      print('[BEACON] Visible beacons (${beaconDataPriorityQueue.length}): strongest=${beaconDataPriorityQueue.first.name} (RSSI=${beaconDataPriorityQueue.first.rssi})');
      print(tempString);

      // Pick the beacon with the strongest RSSI (closest) if it's above the cutoff
      final nearestBeacon = beaconDataPriorityQueue.first;
      final nearestRssi = int.parse(nearestBeacon.rssi);
      if (nearestRssi > beaconRssiCutoff) {
        print('[BEACON] ✓ Nearest beacon "${nearestBeacon.name}" RSSI=$nearestRssi is above cutoff=$beaconRssiCutoff → setting as current location');
        setCurrentLocation(nearestBeacon.uuid);
      } else {
        print('[BEACON] ✗ Nearest beacon "${nearestBeacon.name}" RSSI=$nearestRssi is below cutoff=$beaconRssiCutoff → too far, ignoring');
      }
    }
  }

  void setCurrentLocation(String uuid) {
    final navController = Get.find<NavigationController>();
    currentLocation.value = poiList.firstWhere(
        (element) => element.nodeESP32ID.toLowerCase() == uuid.toLowerCase());
    navController.setCurrentLocation(currentLocation.value);
    haveCurrentLocation.value = true;

    // نُعيد ضبط الـ timer دائمًا عند كل beacon يصل —
    // سواء كان الـ timer شغّالًا أو لا، نريد دائمًا 5 ثواني كاملة من آخر إشارة.
    cancelTimer();
    startTimer(5);

    print(
        "[BEACON] ✓ Set Current location: ${currentLocation.value.name} (NodeID: ${currentLocation.value.nodeID})");
  }

  String get printList {
    var tempString = "";
    beaconDataPriorityQueue.forEach((element) {
      tempString += "${element.name} : ${element.rssi}\n";
    });
    return tempString;
  }

  void fetchLocationInfo() {
    var loc1 = LocationInfo(
      name: 'مدخل النواب',
      nodeID: 1,
    );
    var loc2 = LocationInfo(
      name: 'طرقة',
      nodeID: 3,
    );
    var loc3 = LocationInfo(
      name: 'تقاطع',
      nodeID: 4,
    );
    var loc4 = LocationInfo(
      name: 'Hardware Lab 1',
      nodeID: 6,
    );
    var loc5 = LocationInfo(
      name: 'SCSE Lounge',
      nodeID: 7,
    );
    var loc6 = LocationInfo(
      name: 'Software Lab 1',
      nodeID: 7,
    );
    var loc7 = LocationInfo(
      name: 'Software Lab 3',
      nodeID: 8,
    );
    var loc8 = LocationInfo(
      name: 'Software Project Lab',
      nodeID: 12,
    );
    var loc9 = LocationInfo(
      name: 'Hardware Lab 3',
      nodeID: 14,
    );

    locationList = [
      loc1,
      loc2,
      loc3,
      loc4,
      loc5,
      loc6,
      loc7,
      loc8,
      loc9,
    ];
  }

  void fetchPoiNodes() {
    var node1 = POINode(
      nodeID: 1,
      level: 1,
      nearestLift: 3,
      nodeName: 'POI Node 1',
      nodeESP32ID: '00000000-0000-0000-0000-000000000001',
      neighbourArray: [
        NeighbourNode(
          nodeID: 2,
          heading: 270,
          distanceTo: 5,
        ),
      ],
      section: 'C',
      x: 11,
      y: 21,
      name: 'Hardware Project Lab',
      poiType: POIType.poi,
    );

    var node2 = POINode(
      nodeID: 2,
      level: 1,
      nearestLift: 3,
      nodeName: 'POI Node 2',
      nodeESP32ID: '00000000-0000-0000-0000-000000000002',
      neighbourArray: [
        NeighbourNode(
          nodeID: 1,
          heading: 90,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 3,
          heading: 0,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 4,
          heading: 270,
          distanceTo: 5,
        ),
      ],
      name: 'Intersection',
      section: 'B-C',
      x: 11,
      y: 16,
      poiType: POIType.intersection,
    );

    var node3 = POINode(
      nodeID: 3,
      level: 1,
      nearestLift: 3,
      nextLevelLift: 10,
      nodeName: 'POI Node 3',
      nodeESP32ID: '00000000-0000-0000-0000-000000000003',
      neighbourArray: [
        NeighbourNode(
          nodeID: 2,
          heading: 180,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 10,
          levelNavigation: LevelNavigation.go_down,
        ),
      ],
      name: 'Software Lab 2',
      section: 'B-C',
      x: 6,
      y: 16,
      poiType: POIType.poi,
    );

    var node4 = POINode(
      nodeID: 4,
      level: 1,
      nearestLift: 3,
      nodeName: 'POI Node 4',
      nodeESP32ID: '00000000-0000-0000-0000-000000000004',
      neighbourArray: [
        NeighbourNode(
          nodeID: 2,
          heading: 90,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 5,
          heading: 270,
          distanceTo: 5,
        ),
      ],
      name: 'Hardware Lab 2',
      section: 'B',
      x: 11,
      y: 11,
      poiType: POIType.poi,
    );

    var node5 = POINode(
      nodeID: 5,
      level: 1,
      nearestLift: 6,
      nodeName: 'POI Node 5',
      nodeESP32ID: '00000000-0000-0000-0000-000000000005',
      neighbourArray: [
        NeighbourNode(
          nodeID: 4,
          heading: 90,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 6,
          heading: 0,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 7,
          heading: 270,
          distanceTo: 5,
        ),
      ],
      name: 'Intersection',
      section: 'A-B',
      x: 11,
      y: 6,
      poiType: POIType.intersection,
    );

    var node6 = POINode(
      nodeID: 6,
      level: 1,
      nearestLift: 6,
      nextLevelLift: 14,
      nodeName: 'POI Node 6',
      nodeESP32ID: '00000000-0000-0000-0000-000000000006',
      neighbourArray: [
        NeighbourNode(
          nodeID: 5,
          heading: 180,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 14,
          levelNavigation: LevelNavigation.go_down,
        ),
      ],
      name: 'Hardware Lab 1',
      section: 'A-B',
      x: 6,
      y: 6,
      poiType: POIType.poi,
    );

    var node7 = POINode(
      nodeID: 7,
      level: 1,
      nearestLift: 6,
      nodeName: 'POI Node 7',
      nodeESP32ID: '00000000-0000-0000-0000-000000000007',
      neighbourArray: [
        NeighbourNode(
          nodeID: 5,
          heading: 90,
          distanceTo: 5,
        ),
      ],
      name: 'SCSE Lounge / Software Lab 1',
      section: 'A',
      x: 11,
      y: 1,
      poiType: POIType.poi,
    );

    var node8 = POINode(
      nodeID: 8,
      level: 0,
      nearestLift: 10,
      nodeName: 'POI Node 8',
      nodeESP32ID: '00000000-0000-0000-0000-000000000008',
      neighbourArray: [
        NeighbourNode(
          nodeID: 9,
          heading: 270,
          distanceTo: 5,
        ),
      ],
      name: 'Software Lab 3',
      section: 'C',
      x: 1,
      y: 21,
      poiType: POIType.poi,
    );

    var node9 = POINode(
      nodeID: 9,
      level: 0,
      nearestLift: 10,
      nodeName: 'POI Node 9',
      nodeESP32ID: '00000000-0000-0000-0000-000000000009',
      neighbourArray: [
        NeighbourNode(
          nodeID: 8,
          heading: 90,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 10,
          heading: 180,
          distanceTo: 5,
        ),
      ],
      name: 'Intersection',
      section: 'B-C',
      x: 1,
      y: 16,
      poiType: POIType.intersection,
    );

    var node10 = POINode(
      nodeID: 10,
      level: 0,
      nearestLift: 10,
      nextLevelLift: 3,
      nodeName: 'POI Node 10',
      nodeESP32ID: '00000000-0000-0000-0000-00000000000a',
      neighbourArray: [
        NeighbourNode(
          nodeID: 9,
          heading: 0,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 11,
          heading: 180,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 3,
          levelNavigation: LevelNavigation.go_up,
        ),
      ],
      name: 'Intersection',
      section: 'B-C',
      x: 6,
      y: 16,
      poiType: POIType.intersection,
    );

    var node11 = POINode(
      nodeID: 11,
      level: 0,
      nearestLift: 10,
      nodeName: 'POI Node 11',
      nodeESP32ID: '00000000-0000-0000-0000-00000000000b',
      neighbourArray: [
        NeighbourNode(
          nodeID: 10,
          heading: 0,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 12,
          heading: 270,
          distanceTo: 5,
        ),
      ],
      name: 'Intersection',
      section: 'B-C',
      x: 11,
      y: 16,
      poiType: POIType.intersection,
    );

    var node12 = POINode(
      nodeID: 12,
      level: 0,
      nearestLift: 14,
      nodeName: 'POI Node 12',
      nodeESP32ID: '00000000-0000-0000-0000-00000000000c',
      neighbourArray: [
        NeighbourNode(
          nodeID: 11,
          heading: 90,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 13,
          heading: 270,
          distanceTo: 5,
        ),
      ],
      name: 'Software Project Lab',
      section: 'B',
      x: 11,
      y: 11,
      poiType: POIType.poi,
    );

    var node13 = POINode(
      nodeID: 13,
      level: 0,
      nearestLift: 14,
      nextLevelLift: 6,
      nodeName: 'POI Node 13',
      nodeESP32ID: '00000000-0000-0000-0000-00000000000d',
      neighbourArray: [
        NeighbourNode(
          nodeID: 12,
          heading: 90,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 14,
          heading: 0,
          distanceTo: 5,
        ),
      ],
      name: 'Intersection',
      section: 'A-B',
      x: 11,
      y: 6,
      poiType: POIType.intersection,
    );

    var node14 = POINode(
      nodeID: 14,
      level: 0,
      nearestLift: 14,
      nextLevelLift: 6,
      nodeName: 'POI Node 14',
      nodeESP32ID: '00000000-0000-0000-0000-00000000000e',
      neighbourArray: [
        NeighbourNode(
          nodeID: 13,
          heading: 180,
          distanceTo: 5,
        ),
        NeighbourNode(
          nodeID: 6,
          levelNavigation: LevelNavigation.go_up,
        ),
      ],
      name: 'Hardware Lab 3',
      section: 'A-B',
      x: 6,
      y: 6,
      poiType: POIType.poi,
    );

    poiList = [
      node1,
      node2,
      node3,
      node4,
      node5,
      node6,
      node7,
      node8,
      node9,
      node10,
      node11,
      node12,
      node13,
      node14
    ];
    for (var i = 1; i <= 14; i++) {
      poiNodes[i] = poiList[i - 1];
    }
  }
}
