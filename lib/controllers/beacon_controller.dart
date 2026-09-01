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
import 'package:pathfinder/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:pathfinder/features/navigation/domain/entities/building_graph.dart';
import 'package:pathfinder/features/navigation/domain/entities/nav_node.dart';
import 'package:pathfinder/features/navigation/domain/entities/nav_edge.dart';

/// نتيجة حساب الـ weighted position: النقطة الأقرب للمركز المرجح + المسافة
/// الفعلية بينهم بالمتر (محتاجينها في hysteresis عشان نقرر التبديل من عدمه)
class _WeightedMatch {
  final POINode node;
  final double distance;
  _WeightedMatch(this.node, this.distance);
}

class BeaconController extends GetxController {
  var poiNodes = <int, POINode>{};
  var poiList = <POINode>[];
  var locationList = <LocationInfo>[];
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
  int beaconRssiCutoff = -50;

  // ── Hysteresis ضد تذبذب RSSI ──────────────────────────────────────────
  // من غير قفل، أي اهتزاز بسيط في الإشارة (تداخل/انعكاس) بيخلي أقرب نقطة
  // للـ weighted center تتقلب بين نقطتين كل شوية حتى لو المستخدم واقف
  // مكانه (ده اللي كان بيحصل بالظبط بين node 207 و209 في اللوج). الحل:
  // نفضل على النقطة "المقفولة" حاليًا، ومنسمحش بالتبديل لنقطة تانية إلا
  // لو قريب قوي منها فعلاً (مسافة صغيرة) وبإشارة مش ضعيفة، أو لو الدور
  // اتغير خالص (انتقال حقيقي عبر أسانسير/سلم مش تذبذب).
  int? _lockedNodeId;
  int? _lockedFloor;
  static const double _switchDistanceMeters = 1.5;
  static const int _switchRssiThreshold = -75;

  Timer? _timer;
  int _timerTime = 0;
  Timer? _scanRestartTimer;

  POINode? destinationLocation;

  // Shared instance registered once in main.dart
  final FlutterReactiveBle _ble = Get.find<FlutterReactiveBle>();

  // Stream subscription for BLE device scanning
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  bool _isRanging = false;

  // ── Watchdog ضد موت السكان بصمت ──────────────────────────────────────
  // أندرويد أحيانًا بيوقف تسليم نتائج الـ BLE scan من غير ما يبعت onDone
  // أو onError (خصوصًا بعد سكان مستمر لفترة، أو قفل الشاشة/توفير الطاقة).
  // في الحالة دي _isRanging بتفضل true للأبد و beaconInitPlatformState()
  // بيرفض يعيد المحاولة (بسبب الـ guard بتاعه) رغم إن مفيش سكان فعلي شغال
  // — وده بالظبط سبب "التطبيق بيفقد تحديد الموقع بعد مدة حتى لو في بيكون
  // قريب". الحل: تايمر دوري بيتابع "آخر نشاط سكان حقيقي" (أي جهاز BLE
  // اتلقط، مش بس بيكون متطابق)، ولو عدّى وقت طويل من غير نشاط، يجبر إعادة
  // تشغيل السكان بالكامل بغض النظر عن قيمة _isRanging.
  DateTime _lastScanActivity = DateTime.now();
  Timer? _watchdogTimer;
  static const _watchdogInterval = Duration(seconds: 10);
  static const _staleThreshold = Duration(seconds: 20);

  Comparator<BeaconData> rssiComparator = (a, b) => int.parse(b.rssi).compareTo(int.parse(a.rssi));
  final beaconDataPriorityQueue = List<BeaconData>.empty().obs;

  // المتغيرات الجديدة لتتبع حالة التحميل من Repository
  late NavigationRepository _navigationRepository;
  BuildingGraph? _currentGraph;
  bool _graphLoaded = false;
  // الـ Future بتاع تحميل بيانات الخريطة — beaconInitPlatformState() بينتظرها
  // قبل ما يبدأ فعليًا، عشان مايبدأش يقارن بيكونات متلقطة مع poiList لسه
  // فاضية (سباق/race condition كان بيسبب "Timer expired" غلط حتى مع وجود
  // بيكون فعلي، لأن التايمر كان بيبدأ العد قبل ما البيانات توصل من Supabase).
  late Future<void> _dataLoadFuture;

  @override
  void onInit() {
    super.onInit();
    // الآن نستخدم async loading من Repository
    _dataLoadFuture = _loadNavigationData();

    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) => _checkScanHealth());
  }

  /// يفحص هل السكان لسه فعليًا شغال (مش بس _isRanging == true نظريًا).
  /// لو مفيش أي نشاط سكان حقيقي (حتى لو من أجهزة BLE مش متطابقة) من
  /// وقت أطول من _staleThreshold، يبقى السكان مات بصمت — نجبر إعادة تشغيله.
  void _checkScanHealth() {
    if (!_isRanging) return; // مفيش سكان مفروض يكون شغال أصلاً دلوقتي
    final idleFor = DateTime.now().difference(_lastScanActivity);
    if (idleFor >= _staleThreshold) {
      print(
          '[BEACON] ⚠️ Watchdog: no scan activity for ${idleFor.inSeconds}s رغم إن _isRanging=true — السكان مات بصمت، جاري إعادة التشغيل بالقوة');
      _forceRestartScan();
    }
  }

  void _forceRestartScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isRanging = false;
    _lastScanActivity = DateTime.now();
    beaconInitPlatformState();
  }

  /// يحمّل البيانات من NavigationRepository (async)
  Future<void> _loadNavigationData() async {
    try {
      print('[BEACON] Loading navigation data from repository...');
      _navigationRepository = Get.find<NavigationRepository>();
      
      // تحميل الـ graph من Repository
      _currentGraph = await _navigationRepository.loadGraph();
      
      if (_currentGraph == null) {
        print('[BEACON] ❌ Graph is null — Supabase returned empty data');
        print('[BEACON] Make sure tables are populated in Supabase');
        return;
      }

      // تحويل البيانات الحقيقية
      _convertGraphToPoiNodes(_currentGraph!);
      _convertGraphToLocationList(_currentGraph!);
      
      _graphLoaded = true;
      print('[BEACON] ✓ Navigation data loaded successfully. Nodes: ${poiList.length}, Locations: ${locationList.length}');
    } catch (e) {
      print('[BEACON] ❌ Error loading data from Supabase: $e');
    }
  }

  /// تحويل BuildingGraph → poiList + poiNodes
  void _convertGraphToPoiNodes(BuildingGraph graph) {
    poiList.clear();
    poiNodes.clear();

    for (final navNode in graph.nodesById.values) {
      // الحصول على رقم الدور من NavLevel
      final level = graph.levelsById[navNode.levelId];
      final levelOrder = level?.order ?? 0;

      // بناء neighbourArray من الـ adjacency
      final neighbours = _buildNeighbours(graph, navNode.id);

      // تحويل NavNode → POINode (للتوافق مع الكود القديم)
      final poiNode = POINode(
        nodeID: navNode.id,
        level: levelOrder, // استخدام order بدل levelId string
        nearestLift: 0, // الحقول القديمة ما في بديل مباشر لها، نحط 0
        nodeName: navNode.nameAr,
        nodeESP32ID: navNode.esp32Uuid ?? 'unknown-${navNode.id}', // استخدام esp32Uuid أو توليد معرّف بديل
        neighbourArray: neighbours,
        name: navNode.nameAr,
        // الاسم الإنجليزي — بيوصل هنا دلوقتي بدل ما يترمى زي الأول، ده
        // اللي بيستخدمه NavigationScreenController._syncIdleState() لعرض
        // "أنت الآن في" بالإنجليزي لو التطبيق شغال بالإنجليزي.
        nameEn: navNode.nameEn,
        section: navNode.type == NavNodeType.poi ? 'POI' : 'INT',
        x: (navNode.x ?? 0).toDouble(),
        y: (navNode.y ?? 0).toDouble(),
        poiType: navNode.type == NavNodeType.poi ? POIType.poi : POIType.intersection,
      );

      poiList.add(poiNode);
      poiNodes[navNode.id] = poiNode;
    }

    print('[BEACON] Converted ${poiList.length} nodes from graph');
    print('[BEACON] DEBUG: All loaded node UUIDs:');
    for (var node in poiList) {
      print('  - Node ${node.nodeID}: ${node.nodeESP32ID}');
    }
  }

  /// بناء neighbourArray من الـ adjacency في الـ graph
  List<NeighbourNode> _buildNeighbours(BuildingGraph graph, int nodeId) {
    final neighbours = <NeighbourNode>[];
    final edges = graph.adjacency[nodeId] ?? [];

    for (final edge in edges) {
      // حساب heading من الإحداثيات
      final fromNode = graph.nodesById[edge.fromNodeId];
      final toNode = graph.nodesById[edge.toNodeId];

      if (fromNode == null || toNode == null) continue;

      final double heading = _calculateHeading(
        fromNode.x ?? 0,
        fromNode.y ?? 0,
        toNode.x ?? 0,
        toNode.y ?? 0,
      );

      // تحديد levelNavigation إذا كانت حافة رأسية
      LevelNavigation levelNav = LevelNavigation.empty;
      if (edge.kind == NavEdgeKind.stairs || edge.kind == NavEdgeKind.elevator) {
        if (edge.verticalDirection == VerticalDirection.up) {
          levelNav = LevelNavigation.go_up;
        } else if (edge.verticalDirection == VerticalDirection.down) {
          levelNav = LevelNavigation.go_down;
        }
      }

      neighbours.add(NeighbourNode(
        nodeID: edge.toNodeId,
        heading: heading,
        distanceTo: edge.distanceMeters,
        levelNavigation: levelNav,
      ));
    }

    return neighbours;
  }

  /// حساب heading (اتجاه) من إحداثيتين
  double _calculateHeading(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final radians = math.atan2(dy, -dx); // السالب يعكس المحور
    final degrees = (radians * 180 / math.pi + 360) % 360;
    return degrees;
  }

  /// تحويل BuildingGraph → locationList (LocationInfo)، مباشرة من
  /// [BuildingGraph.destinations] مش من العقد مباشرة — نفس السبب اللي
  /// NavigationScreenController._buildDestinationList() بيستخدمه: الوجهة
  /// الواحدة ممكن تربط بأكتر من عقدة (زي مدخل كبير)، والعكس:
  /// عقدة واحدة ممكن تمثّل أكتر من وجهة.
  void _convertGraphToLocationList(BuildingGraph graph) {
    locationList.clear();

    for (final destination in graph.destinations) {
      locationList.add(LocationInfo(
        name: destination.nameAr,
        nodeID: destination.primaryNodeId,
      ));
    }

    print('[BEACON] Converted ${locationList.length} locations from graph');
  }



  @override
  void onClose() {
    // ملحوظة: الكلاس ده GetxController مش StatefulWidget، فـ GetX بينادي
    // onClose() تلقائيًا (مش dispose()) لما الـ controller يتشال. كان فيه
    // دالة dispose() هنا قبل كده بس مبتتنفذش أبدًا فعليًا لإن مفيش حد
    // بينادي عليها — التنضيف الحقيقي لازم يكون هنا.
    print('[BEACON] Disposing BeaconController');
    _timer?.cancel();
    _scanRestartTimer?.cancel();
    _watchdogTimer?.cancel();
    _scanSubscription?.cancel();
    super.onClose();
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
      if (_timerTime < 1) {
        timer.cancel();
        _timer = null;
        fetchingBeacons.value = false;
        haveCurrentLocation.value = false;
        print("[BEACON] Timer expired — no beacon found");
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
    // نمنع أي نداء تاني يدخل هنا وهو لسه مستني تحميل البيانات (زي ما بيحصل
    // من MainNavigationScreen.build() اللي بينادي الدالة دي كل ما الشاشة
    // تتبني — عادي جدًا يحصل أكتر من مرة قبل ما التحميل يخلص).
    _isRanging = true;

    // مهم: نستنى تحميل خريطة المبنى من Supabase قبل ما نبدأ فعليًا. من
    // غير كده، لو بيكون اتلقط قبل ما poiList توصل، هيفشل في المطابقة —
    // مش لعيب في البيكون، لكن لأن مفيش داتا نقارن بيها أصلاً، والتايمر
    // كان بيعدي "ملقيناش بيكون" غلط بعد 5 ثواني حتى لو انت واقف جنب واحد
    // حقيقي شغال.
    await _dataLoadFuture;

    if (poiList.isEmpty) {
      print('[BEACON] ⚠️ خريطة المبنى لسه فاضية بعد التحميل (فشل أو Supabase رجّع صفوف فاضية) — هعيد محاولة التحميل والسكان بعد 3 ثواني');
      _isRanging = false;
      _dataLoadFuture = _loadNavigationData();
      _scheduleRestart(delaySeconds: 3);
      return;
    }

    print('[BEACON] Starting BLE scan for ESP32 iBeacon nodes via flutter_reactive_ble');

    startTimer(5);
    _lastScanActivity = DateTime.now();

    _scanSubscription = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen(
      (DiscoveredDevice device) {
        // أي جهاز BLE بيتلقط (حتى لو مش متطابق مع نودة عندنا) بيثبت إن
        // السكان لسه شغال فعليًا — ده اللي الـ watchdog بيتابعه.
        _lastScanActivity = DateTime.now();

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
        print('[BEACON] Scan stream ended (onDone) — scheduling restart in 1s');
        _isRanging = false;
        _scheduleRestart();
      },
      onError: (error) {
        print('[BEACON] Scan stream error: $error — scheduling restart in 3s');
        _isRanging = false;
        _scheduleRestart(delaySeconds: 3);
      },
    );
  }

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

      final major = (bytes[19] << 8) | bytes[18];
      final minor = (bytes[21] << 8) | bytes[20];
      final txPower = -59;

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

    // 2. Existing Apple iBeacon fallback parsing...
    if (bytes.length < 23) return null;

    int offset = -1;

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
    final rawHex = uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
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
    // print('[BEACON] 🔍 Received beacon UUID: ${beaconData.uuid}');
    // print('[BEACON] 📋 Searching in ${poiList.length} loaded nodes...');
    //
    var beaconIndexInList = poiList.indexWhere(
        (beacon) => beacon.nodeESP32ID.toLowerCase() == beaconData.uuid.toLowerCase());

    if (beaconIndexInList == -1) {
      print('[BEACON] ❌ NO MATCH FOUND!');
      print('[BEACON] UUID "${beaconData.uuid}" not in any loaded node');
      print('[BEACON] ⚠️ Make sure this UUID exists in Supabase nodes table with column esp32_uuid');
      print('[BEACON] Expected format: 00000000-0000-0000-0000-000000000005');
      return;
    }
    
    // print('[BEACON] ✅ MATCH FOUND at index $beaconIndexInList!');
    
    var beaconIndexInQueue = beaconDataPriorityQueue.indexWhere(
        (beacon) => beacon.uuid.toLowerCase() == beaconData.uuid.toLowerCase());

    if (beaconIndexInQueue == -1)
      beaconDataPriorityQueue.add(beaconData);
    else {
      beaconDataPriorityQueue[beaconIndexInQueue] = beaconData;
    }

    beaconDataPriorityQueue.removeWhere((item) {
      var diff = DateTime.now().difference(item.dateTime);
      if (diff.inSeconds >= 8) return true;
      return false;
    });

    beaconDataPriorityQueue.sort(rssiComparator);
    var tempString = '';
    for (var item in beaconDataPriorityQueue) {
      tempString += item.name + " : " + item.rssi + '\n';
    }
    beaconResult.value = tempString;
    // print('[BEACON] Visible beacons (${beaconDataPriorityQueue.length}): strongest=${beaconDataPriorityQueue.first.name} (RSSI=${beaconDataPriorityQueue.first.rssi})');

    // ========== Phase 1: استخدم Weighted Centroid بدل Strongest Signal فقط ==========
    final nearestBeacon = beaconDataPriorityQueue.first;
    final nearestRssi = int.parse(nearestBeacon.rssi);
    
    if (nearestRssi > beaconRssiCutoff) {
      // حساب الموقع المرجح من جميع البيكونات المرئية
      print('$beaconDataPriorityQueue');
      final weightedMatch = _calculateWeightedPosition(beaconDataPriorityQueue);

      if (weightedMatch != null) {
        // قبل ما نستخدم النقطة المرشحة، نمررها على الـ hysteresis عشان مانقفزش بين
        // نقطتين بسبب تذبذب الإشارة
        final resolvedNode = _resolveNodeWithHysteresis(
            weightedMatch.node, weightedMatch.distance, nearestRssi);
        setCurrentLocationFromNode(resolvedNode);
        print('[BEACON] ✓ Weighted position: Node ${resolvedNode.nodeID} ${resolvedNode.nodeESP32ID} (${resolvedNode.name})');
      } else {
        // Fallback: استخدم أقوي بيكون إذا فشل الحساب المرجح
        setCurrentLocationFromUuid(nearestBeacon.uuid);
      }
    }
  }

  void setCurrentLocation(String uuid) {
    final navController = Get.find<NavigationController>();
    currentLocation.value = poiList.firstWhere(
        (element) => element.nodeESP32ID.toLowerCase() == uuid.toLowerCase());
    navController.setCurrentLocation(currentLocation.value);
    haveCurrentLocation.value = true;

    cancelTimer();
    startTimer(5);

    // print(
    //     "[BEACON] ✓ Set Current location: ${currentLocation.value.name} (NodeID: ${currentLocation.value.nodeID})");
  }

  String get printList {
    var tempString = "";
    beaconDataPriorityQueue.forEach((element) {
      tempString += "${element.name} : ${element.rssi}\n";
    });
    return tempString;
  }

  /// حساب الموقع المرجح من قائمة البيكونات المرئية
  /// باستخدام صيغة: weight_i = 10^(RSSI_i / 10)
  /// ثم البحث عن أقرب node للمركز الهندسي المرجح
  /// حساب الموقع المرجح من قائمة البيكونات المرئية
  /// باستخدام صيغة: weight_i = 10^(RSSI_i / 10)
  /// ثم البحث عن أقرب node للمركز الهندسي المرجح **في نفس الدور فقط**
  ///
  /// FIX: الإحداثيات (x,y) محلية لكل دور — لو بحثنا في كل الدوور،
  /// قد نختار node من دور غلط (نفس x,y لكن floor مختلف)
  _WeightedMatch? _calculateWeightedPosition(List<BeaconData> visibleBeacons) {
    if (visibleBeacons.isEmpty) return null;

    // خطوة 1: احصل على البيكون الأقوي لتحديد الدور الحالي
    final strongestBeacon = visibleBeacons.first;
    final strongestNode = poiList.firstWhereOrNull(
            (n) => n.nodeESP32ID.toLowerCase() == strongestBeacon.uuid.toLowerCase());

    if (strongestNode == null) return null;

    final currentFloor = strongestNode.level;
    print('[BEACON] 🏢 Detected floor: $currentFloor (from strongest beacon: ${strongestBeacon.name})');

    double totalWeight = 0;
    double weightedX = 0;
    double weightedY = 0;
    int validBeacons = 0;

    // خطوة 2: احسب المركز المرجح من البيكونات المرئية
    for (final beacon in visibleBeacons) {
      final rssi = int.parse(beacon.rssi);
      // صيغة log-distance: weight = 10^(RSSI/10)
      final weight = math.pow(10, rssi / 10.0).toDouble();

      // ابحث عن node هذا البيكون
      final node = poiList.firstWhereOrNull(
              (n) => n.nodeESP32ID.toLowerCase() == beacon.uuid.toLowerCase());

      if (node == null) continue;

      totalWeight += weight;
      weightedX += node.x * weight;
      weightedY += node.y * weight;
      validBeacons++;
    }

    if (totalWeight == 0 || validBeacons == 0) return null;

    // المركز الهندسي المرجح
    final centerX = weightedX / totalWeight;
    final centerY = weightedY / totalWeight;

    print('[BEACON] 📍 Weighted center: ($centerX, $centerY) from $validBeacons beacons on floor $currentFloor');

    // خطوة 3: ابحث عن أقرب node **في نفس الدور فقط**
    // هذا حل لمشكلة الإحداثيات المحلية: كل دور له نسخته الخاصة من (x,y)
    POINode? nearest;
    double minDistance = double.infinity;

    final nodesInCurrentFloor = poiList.where((n) => n.level == currentFloor).toList();
    print('[BEACON] 🔍 Searching in ${nodesInCurrentFloor.length} nodes on floor $currentFloor (from ${poiList.length} total)');

    for (final node in nodesInCurrentFloor) {
      final dist = math.sqrt(
          math.pow(node.x - centerX, 2) +
              math.pow(node.y - centerY, 2)
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = node;
      }
    }

    if (nearest != null) {
      print('[BEACON] ✅ Matched to: Node ${nearest.nodeID} "${nearest.name}" (floor $currentFloor, distance: ${minDistance.toStringAsFixed(2)}m)');
    }

    return nearest == null ? null : _WeightedMatch(nearest, minDistance);
  }

  /// يقرر هل نسمح بتغيير النقطة المقفولة للنقطة المرشحة الجديدة، أو نفضل
  /// على النقطة القديمة (Hysteresis ضد تذبذب RSSI).
  ///
  /// قواعد التبديل:
  /// 1. لو مفيش قفل حالي (أول قراءة) → نقفل على المرشح فورًا.
  /// 2. لو المرشح نفسه النقطة المقفولة → نستمر عليها زي ما هي.
  /// 3. لو الدور اتغير خالص (طابق مختلف) → نسمح بالتبديل فورًا (انتقال
  ///    حقيقي عبر أسانسير/سلم، مش تذبذب).
  /// 4. غير كده، نسمح بالتبديل فقط لو:
  ///    - المسافة للمرشح من الـ weighted center أقل من أو تساوي
  ///      [_switchDistanceMeters] (قريب قوي فعلاً من النقطة الجديدة)، و
  ///    - أقوى إشارة ملتقطة أقوى من أو تساوي [_switchRssiThreshold]
  ///      (مش إشارة ضعيفة ممكن تكون تشويش).
  /// لو الشرطين مش متحققين، نفضل على النقطة القديمة المقفولة ولو الإشارة
  /// ضعيفة منسمحشش بأي تبديل خالص لحد ما تقوى.
  POINode _resolveNodeWithHysteresis(
      POINode candidate, double distanceToCandidate, int nearestRssi) {
    if (_lockedNodeId == null) {
      _lockedNodeId = candidate.nodeID;
      _lockedFloor = candidate.level;
      return candidate;
    }

    if (candidate.nodeID == _lockedNodeId) {
      return candidate;
    }

    final floorChanged = candidate.level != _lockedFloor;
    final closeEnough = distanceToCandidate <= _switchDistanceMeters;
    final strongEnough = nearestRssi >= _switchRssiThreshold;

    if (floorChanged || (closeEnough && strongEnough)) {
      print('[BEACON] 🔓 تبديل القفل: من Node $_lockedNodeId إلى Node ${candidate.nodeID} '
          '(floorChanged=$floorChanged, distance=${distanceToCandidate.toStringAsFixed(2)}m, rssi=$nearestRssi)');
      _lockedNodeId = candidate.nodeID;
      _lockedFloor = candidate.level;
      return candidate;
    }

    final lockedNode = poiNodes[_lockedNodeId];
    if (lockedNode == null) {
      // احتياطي: لو النقطة المقفولة اختفت من poiNodes لأي سبب، نقفل على المرشح
      _lockedNodeId = candidate.nodeID;
      _lockedFloor = candidate.level;
      return candidate;
    }

    print('[BEACON] 🔒 محافظ على القفل عند Node $_lockedNodeId '
        '(المرشح ${candidate.nodeID} بعيد=${distanceToCandidate.toStringAsFixed(2)}m أو إشارة ضعيفة=$nearestRssi)');
    return lockedNode;
  }

  /// تحديث الموقع من POINode مباشرة (بعد حساب weighted position)
  void setCurrentLocationFromNode(POINode location) {
    final navController = Get.find<NavigationController>();
    currentLocation.value = location;
    navController.setCurrentLocation(currentLocation.value);
    haveCurrentLocation.value = true;

    cancelTimer();
    startTimer(5);
  }

  /// تحديث الموقع من UUID (الطريقة القديمة — للـ fallback فقط)
  void setCurrentLocationFromUuid(String uuid) {
    final navController = Get.find<NavigationController>();
    currentLocation.value = poiList.firstWhere(
        (element) => element.nodeESP32ID.toLowerCase() == uuid.toLowerCase());
    navController.setCurrentLocation(currentLocation.value);
    haveCurrentLocation.value = true;

    cancelTimer();
    startTimer(5);
  }

}
