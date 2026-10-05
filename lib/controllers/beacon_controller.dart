import '../core/utils/app_logger.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide VerticalDirection;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:parliament_ips/models/beacon_data.dart';
import 'package:parliament_ips/models/location.dart';
import 'package:parliament_ips/models/neighbour_node.dart';
import 'package:parliament_ips/models/poinode.dart';
import 'package:parliament_ips/utils/constants.dart';
import 'package:permission_handler/permission_handler.dart';

import 'navigation_controller.dart';
import 'package:parliament_ips/features/navigation/controllers/navigation_controller.dart' as modern_nav;
import 'package:parliament_ips/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:parliament_ips/features/navigation/domain/entities/building_graph.dart';
import 'package:parliament_ips/features/navigation/domain/entities/nav_node.dart';
import 'package:parliament_ips/features/navigation/domain/entities/nav_edge.dart';

/// نتيجة حساب الـ weighted position: النقطة الأقرب للمركز المرجح + المسافة
/// الفعلية بينهم بالمتر والإحداثيات المستمرة (x,y)
class _WeightedMatch {
  final POINode node;
  final double distance;
  final double centerX;
  final double centerY;
  _WeightedMatch(this.node, this.distance, this.centerX, this.centerY);
}

class BeaconController extends GetxController with WidgetsBindingObserver {
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

  /// الإحداثيات المستمرة التقديرية الحالية (X, Y) بالمتر على خريطة الدور
  final currentCoordinates = Rx<math.Point<double>?>(null);

  /// ذاكرة تنعيم الإشارة (EMA Filter) لكل بيكون لتقليل القفزات
  final Map<String, double> _filteredRssiByUuid = {};

  /// وقت آخر حساب للموقع التقديري لتطبيق Throttling
  DateTime _lastPositionProcessTime = DateTime.now();
  static const _positionThrottleMs = 450;

  var fetchingBeacons = true.obs;
  var haveCurrentLocation = false.obs;
  var beaconResult = ''.obs;

  /// تم توسيع العتبة من -75 إلى -85 لضمان عدم فقدان التموضع بسبب التأرجح الطبيعي للبلوتوث
  int beaconRssiCutoff = -85;

  // لتجنب تكرار طباعة اللوج لنفس النود في كل جزء من الثانية
  final Map<String, DateTime> _lastLogTimePerNode = {};

  // ── Hysteresis ضد تذبذب RSSI ──────────────────────────────────────────
  int? _lockedNodeId;
  int? _lockedFloor;
  static const double _switchDistanceMeters = 2.8;
  static const int _switchRssiThreshold = -85;
  static const int defaultScanTimerSeconds = 12;

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
  DateTime _lastScanActivity = DateTime.now();
  Timer? _watchdogTimer;
  static const _watchdogInterval = Duration(seconds: 10);
  static const _staleThreshold = Duration(seconds: 20);

  Comparator<BeaconData> rssiComparator = (a, b) =>
      int.parse(b.rssi).compareTo(int.parse(a.rssi));
  final beaconDataPriorityQueue = List<BeaconData>.empty().obs;

  /// مجموعة النودز الفيزيائية المعطلة أو المفصولة التي تم تحويلها تلقائياً إلى نودز افتراضية (Virtual Fallback)
  final RxSet<int> virtualFallbackNodes = <int>{}.obs;

  bool isVirtualFallback(int nodeId) => virtualFallbackNodes.contains(nodeId);

  Timer? _beaconExpiryTimer;
  static const _beaconStaleDuration = Duration(milliseconds: 3500);

  late NavigationRepository _navigationRepository;
  BuildingGraph? _currentGraph;
  BuildingGraph? get currentGraph => _currentGraph;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // 1. تفعيل فوري لبيانات الكاش المحلي وبدء مسح البلوتوث فوراً (0ms تأخير)
    _initFastCacheAndScan();

    _watchdogTimer = Timer.periodic(
      _watchdogInterval,
      (_) => _checkScanHealth(),
    );

    // فحص دوري كل 800ms لحذف البيكونات المنقطعة وكشف التقاطعات المعطلة
    _beaconExpiryTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _checkBeaconExpirations(),
    );
  }

  /// تحميل فوري وسريع للكاش المحلي المتاح (ينتهي خلال ~10ms) وبدء مسح البلوتوث فوراً
  Future<void> _initFastCacheAndScan() async {
    _navigationRepository = Get.find<NavigationRepository>();

    // 1. محاولة استرجاع الكاش المحلي المتاح فوراً دون أي اتصال بالإنترنت
    try {
      final cachedGraph = await _navigationRepository.loadCachedGraph();
      if (cachedGraph != null) {
        _currentGraph = cachedGraph;
        _convertGraphToPoiNodes(cachedGraph);
        _convertGraphToLocationList(cachedGraph);
        AppLogger.debug(
          '[BEACON] ⚡ تم تفعيل بيانات الكاش المحلي فوراً (${poiList.length} نود) — جاهز لتحديد الموقع فوراً',
        );
      }
    } catch (e) {
      AppLogger.debug('[BEACON] ⚠️ خطأ في قراءة الكاش الأولي: $e');
    }

    // 2. تشغيل مسح البلوتوث فوراً دون أي انتظار لشبكة سوبابيز!
    beaconInitPlatformState();

    // 3. جلب وتحديث أحدث بيانات من سوبابيز في الخلفية دون تعطيل واجهة المستخدم
    unawaited(_loadNavigationData());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.debug('[BEACON] 📱 AppLifecycleState changed to: $state');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseScanForBackground();
    } else if (state == AppLifecycleState.resumed) {
      _resumeScanFromForeground();
    }
  }

  void _pauseScanForBackground() {
    AppLogger.debug('[BEACON] ⏸️ إيقاف مسح البلوتوث بأمان في الخلفية...');
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanRestartTimer?.cancel();
    _scanRestartTimer = null;
    _isRanging = false;
    beaconDataPriorityQueue.clear();
  }

  void _resumeScanFromForeground() {
    AppLogger.debug('[BEACON] ▶️ استئناف مسح البلوتوث بعد العودة للواجهة...');
    _isRanging = false;
    _lastScanActivity = DateTime.now();
    beaconInitPlatformState();
  }

  /// يفحص هل السكان لسه فعليًا شغال (مش بس _isRanging == true نظريًا).
  void _checkScanHealth() {
    if (!_isRanging) return;
    final idleFor = DateTime.now().difference(_lastScanActivity);
    if (idleFor >= _staleThreshold) {
      AppLogger.debug(
        '[BEACON] ⚠️ Watchdog: no scan activity for ${idleFor.inSeconds}s — إعادة تشغيل السكان بالقوة',
      );
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

  /// يحمّل أحدث البيانات من NavigationRepository في الخلفية (Stale-While-Revalidate)
  Future<void> _loadNavigationData() async {
    try {
      AppLogger.debug('[BEACON] 🌐 جارِ تحديث بيانات الخريطة من سوبابيز في الخلفية...');
      _navigationRepository = Get.find<NavigationRepository>();

      // تحميل الـ graph من Repository (forceRefresh = true لجلب الأحدث من الشبكة)
      final freshGraph = await _navigationRepository.loadGraph(forceRefresh: true);

      _currentGraph = freshGraph;

      // تحويل البيانات الحقيقية وتحديث القوائم
      _convertGraphToPoiNodes(freshGraph);
      _convertGraphToLocationList(freshGraph);

      AppLogger.debug(
        '[BEACON] ✓ تم تحديث الخريطة بنجاح من سوبابيز. Nodes: ${poiList.length}, Locations: ${locationList.length}',
      );

      // تحديث شاشة الملاحة بالقائمة الجديدة والوجهات المحدثة
      if (Get.isRegistered<modern_nav.NavigationScreenController>()) {
        Get.find<modern_nav.NavigationScreenController>().onGraphUpdated(freshGraph);
      }

      // إذا كان قد تم تحديد الموقع بالفعل بالكاش، نحدث معلومات النود الحالية بالقيم الجديدة
      if (haveCurrentLocation.value) {
        final currentNodeId = currentLocation.value.nodeID;
        final updatedPoi = poiNodes[currentNodeId];
        if (updatedPoi != null) {
          currentLocation.value = updatedPoi;
          final navController = Get.find<NavigationController>();
          navController.setCurrentLocation(updatedPoi);
        }
      } else if (beaconDataPriorityQueue.isNotEmpty) {
        // لو لم نكن قد حددنا الموقع بعد ولكن لدينا بيكونات ملتقطة في الطابور، أعد التقييم فوراً
        _processNearestBeacons();
      }
    } catch (e) {
      AppLogger.debug('[BEACON] ℹ️ تعذر تحديث بيانات سوبابيز (سيستمر العمل بالكاش المحلي): $e');
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
        nodeESP32ID:
            navNode.esp32Uuid ??
            'unknown-${navNode.id}', // استخدام esp32Uuid أو توليد معرّف بديل
        neighbourArray: neighbours,
        name: navNode.nameAr,
        // الاسم الإنجليزي — بيوصل هنا دلوقتي بدل ما يترمى زي الأول، ده
        // اللي بيستخدمه NavigationScreenController._syncIdleState() لعرض
        // "أنت الآن في" بالإنجليزي لو التطبيق شغال بالإنجليزي.
        nameEn: navNode.nameEn,
        section: navNode.type == NavNodeType.poi ? 'POI' : 'INT',
        x: (navNode.x ?? 0).toDouble(),
        y: (navNode.y ?? 0).toDouble(),
        poiType: navNode.type == NavNodeType.poi
            ? POIType.poi
            : POIType.intersection,
      );

      poiList.add(poiNode);
      poiNodes[navNode.id] = poiNode;
    }

    AppLogger.debug('[BEACON] Converted ${poiList.length} nodes from graph');
    AppLogger.debug('[BEACON] DEBUG: All loaded node UUIDs:');
    for (var node in poiList) {
      AppLogger.debug('  - Node ${node.nodeID}: ${node.nodeESP32ID}');
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
      if (edge.kind == NavEdgeKind.stairs ||
          edge.kind == NavEdgeKind.elevator) {
        if (edge.verticalDirection == VerticalDirection.up) {
          levelNav = LevelNavigation.go_up;
        } else if (edge.verticalDirection == VerticalDirection.down) {
          levelNav = LevelNavigation.go_down;
        }
      }

      neighbours.add(
        NeighbourNode(
          nodeID: edge.toNodeId,
          heading: heading,
          distanceTo: edge.distanceMeters,
          levelNavigation: levelNav,
        ),
      );
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
      locationList.add(
        LocationInfo(
          name: destination.nameAr,
          nodeID: destination.primaryNodeId,
        ),
      );
    }

    AppLogger.debug('[BEACON] Converted ${locationList.length} locations from graph');
  }

  @override
  void onClose() {
    AppLogger.debug('[BEACON] Disposing BeaconController');
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _scanRestartTimer?.cancel();
    _watchdogTimer?.cancel();
    _beaconExpiryTimer?.cancel();
    _scanSubscription?.cancel();
    super.onClose();
  }

  void setDestination(int nodeID) {
    destinationLocation = poiList.firstWhere(
      (element) => element.nodeID == nodeID,
    );
  }

  Future<List<LocationInfo>> onSearch(String filter) async {
    return locationList
        .where(
          (element) =>
              element.nodeID != currentLocation.value.nodeID &&
              element.name.contains(filter),
        )
        .toList();
  }

  void startTimer([int? timeSet]) {
    const oneSec = Duration(seconds: 1);
    _timerTime = timeSet ?? defaultScanTimerSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_timerTime < 1) {
        timer.cancel();
        _timer = null;
        fetchingBeacons.value = false;
        // وضع السماح (Grace Mode): أثناء التوجيه النشط لا نسحب الموقع فجأة لتجنب إرباك الشاشة
        final isNavigating = (Get.isRegistered<modern_nav.NavigationScreenController>() &&
                Get.find<modern_nav.NavigationScreenController>().isNavigating.value) ||
            (Get.isRegistered<NavigationController>() &&
                Get.find<NavigationController>().isNavigating);
        if (!isNavigating) {
          haveCurrentLocation.value = false;
        }
        AppLogger.debug("[BEACON] ⏳ انقضت مهلة البحث — لم يتم رصد إشارة بيكون مؤخراً");
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
    _isRanging = true;

    AppLogger.debug(
      '[BEACON] Starting BLE scan for ESP32 iBeacon nodes via flutter_reactive_ble',
    );

    startTimer(defaultScanTimerSeconds);
    _lastScanActivity = DateTime.now();

    _scanSubscription = _ble
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
        .listen(
          (DiscoveredDevice device) {
            // أي جهاز BLE بيتلقط (حتى لو مش متطابق مع نودة عندنا) بيثبت إن
            // السكان لسه شغال فعليًا — ده اللي الـ watchdog بيتابعه.
            _lastScanActivity = DateTime.now();

            final beaconData = _parseIBeacon(device);
            if (beaconData != null) {
              fetchingBeacons.value = false;
              addToListAndSort(beaconData);
            }
          },
          onDone: () {
            AppLogger.debug(
              '[BEACON] Scan stream ended (onDone) — scheduling restart in 1s',
            );
            _isRanging = false;
            _scheduleRestart();
          },
          onError: (error) {
            AppLogger.debug(
              '[BEACON] Scan stream error: $error — scheduling restart in 3s',
            );
            _isRanging = false;
            _scheduleRestart(delaySeconds: 3);
          },
        );
  }

  void _scheduleRestart({int delaySeconds = 1}) {
    _scanRestartTimer?.cancel();
    _scanRestartTimer = Timer(Duration(seconds: delaySeconds), () {
      _scanRestartTimer = null;
      AppLogger.debug('[BEACON] Auto-restarting BLE scan...');
      beaconInitPlatformState();
    });
  }

  BeaconData? _parseIBeacon(DiscoveredDevice device) {
    final bytes = device.manufacturerData;

    // 1. Check for the NEW IPS Custom Protocol (0xFFFF Company ID)
    if (bytes.length >= 26 && bytes[0] == 0xFF && bytes[1] == 0xFF) {
      final uuidBytes = bytes.sublist(2, 18);
      final rawHex = uuidBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final formattedUuid =
          '${rawHex.substring(0, 8)}-${rawHex.substring(8, 12)}-${rawHex.substring(12, 16)}-${rawHex.substring(16, 20)}-${rawHex.substring(20, 32)}'
              .toLowerCase();

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
    final rawHex = uuidBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
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

    if (statuses[Permission.location]!.isGranted ||
        statuses[Permission.bluetoothScan]!.isGranted) {
      await beaconInitPlatformState();
    } else {
      AppLogger.debug("[BEACON] Permissions not granted!");
    }
  }

  void addToListAndSort(BeaconData beaconData) {
    // print('[BEACON] 🔍 Received beacon UUID: ${beaconData.uuid}');
    // print('[BEACON] 📋 Searching in ${poiList.length} loaded nodes...');
    //
    var beaconIndexInList = poiList.indexWhere(
      (beacon) =>
          beacon.nodeESP32ID.toLowerCase() == beaconData.uuid.toLowerCase(),
    );

    if (beaconIndexInList == -1) {
      // جهاز BLE غير مسجل في خريطة المبنى (ساعة/تلفزيون/لابتوب) - نتجاهله بصمت لتنظيف اللوج
      return;
    }

    final matchedNode = poiList[beaconIndexInList];
    final now = DateTime.now();

    // استعادة فورية للنود إذا كانت مسجلة كافتراضية بسبب انقطاع سابق (Self-Healing)
    if (virtualFallbackNodes.contains(matchedNode.nodeID)) {
      virtualFallbackNodes.remove(matchedNode.nodeID);
      AppLogger.debug(
        '[BEACON] 🔄 استعادة إشارة النود [${matchedNode.name}] (Node ID: ${matchedNode.nodeID}) — إلغاء وضع الفيرشوال المؤقت',
      );
    }

    final lastLog = _lastLogTimePerNode[matchedNode.nodeESP32ID];

    // طباعة نظيفة مرة كل ثانيتين لكل نود
    if (lastLog == null || now.difference(lastLog).inSeconds >= 2) {
      _lastLogTimePerNode[matchedNode.nodeESP32ID] = now;
      AppLogger.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      AppLogger.debug(
        '📍 تم رصد نود: [${matchedNode.name}] (Node ID: ${matchedNode.nodeID})',
      );
      AppLogger.debug('   🔑 UUID: ${beaconData.uuid}');
      AppLogger.debug(
        '   📐 الإحداثيات: X=${matchedNode.x}, Y=${matchedNode.y} | الدور: ${matchedNode.level}',
      );
      AppLogger.debug(
        '   📶 قوة الإشارة (RSSI): ${beaconData.rssi} dBm | 📏 المسافة: ~${beaconData.distance}m',
      );
      AppLogger.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    // تنعيم الإشارة (EMA filter) لكل بيكون لمنع التذبذب والقفزات اللحظية
    final rawRssi = double.tryParse(beaconData.rssi) ?? -99.0;
    final uuidKey = beaconData.uuid.toLowerCase();
    final prevRssi = _filteredRssiByUuid[uuidKey] ?? rawRssi;
    final smoothedRssi = 0.35 * rawRssi + 0.65 * prevRssi;
    _filteredRssiByUuid[uuidKey] = smoothedRssi;
    final smoothedRssiInt = smoothedRssi.round();

    beaconData.rssi = smoothedRssiInt.toString();
    beaconData.dateTime = now;
    final txPowerVal = int.tryParse(beaconData.txPower) ?? -59;
    beaconData.distance = _calculateDistance(txPowerVal, smoothedRssiInt).toStringAsFixed(2);

    var beaconIndexInQueue = beaconDataPriorityQueue.indexWhere(
      (beacon) => beacon.uuid.toLowerCase() == beaconData.uuid.toLowerCase(),
    );

    if (beaconIndexInQueue == -1) {
      beaconDataPriorityQueue.add(beaconData);
    } else {
      beaconDataPriorityQueue[beaconIndexInQueue] = beaconData;
    }

    beaconDataPriorityQueue.removeWhere((item) {
      var diff = now.difference(item.dateTime);
      return diff >= _beaconStaleDuration;
    });

    beaconDataPriorityQueue.sort(rssiComparator);
    if (kDebugMode) {
      var tempString = '';
      for (var item in beaconDataPriorityQueue) {
        tempString += item.name + " : " + item.rssi + '\n';
      }
      beaconResult.value = tempString;
    }

    // تنظيف ذاكرة الـ RSSI لتجنب تسريب الرام
    if (_filteredRssiByUuid.length > 50) {
      _filteredRssiByUuid.clear();
    }

    // Throttling: عدم إعادة حساب الموقع المرجح المعقد أكثر من مرتين في الثانية
    // إلا لو كان الموقع الحالي مفقوداً (نحسب فوراً لتحديد الموقع بسرعة)
    final nowTime = DateTime.now();
    if (haveCurrentLocation.value &&
        nowTime.difference(_lastPositionProcessTime).inMilliseconds < _positionThrottleMs) {
      return;
    }
    _lastPositionProcessTime = nowTime;

    // ========== Phase 1: استخدم Weighted Centroid بدل Strongest Signal فقط ==========
    _processNearestBeacons();
  }

  void _processNearestBeacons() {
    if (beaconDataPriorityQueue.isEmpty) return;
    final nearestBeacon = beaconDataPriorityQueue.first;
    final nearestRssi = int.tryParse(nearestBeacon.rssi) ?? -99;

    if (nearestRssi > beaconRssiCutoff) {
      final weightedMatch = _calculateWeightedPosition(beaconDataPriorityQueue);

      if (weightedMatch != null) {
        final resolvedNode = _resolveNodeWithHysteresis(
          weightedMatch.node,
          weightedMatch.distance,
          nearestRssi,
        );
        setCurrentLocationFromNode(resolvedNode);
      } else {
        // Fallback: استخدم أقوي بيكون إذا فشل الحساب المرجح
        setCurrentLocationFromUuid(nearestBeacon.uuid);
      }
    }
  }

  void setCurrentLocation(String uuid) {
    final navController = Get.find<NavigationController>();
    currentLocation.value = poiList.firstWhere(
      (element) => element.nodeESP32ID.toLowerCase() == uuid.toLowerCase(),
    );
    navController.setCurrentLocation(currentLocation.value);
    haveCurrentLocation.value = true;

    cancelTimer();
    startTimer(defaultScanTimerSeconds);

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
      (n) => n.nodeESP32ID.toLowerCase() == strongestBeacon.uuid.toLowerCase(),
    );

    if (strongestNode == null) return null;

    final currentFloor = strongestNode.level;
    // print('[BEACON] 🏢 Detected floor: $currentFloor (from strongest beacon: ${strongestBeacon.name})');

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
        (n) => n.nodeESP32ID.toLowerCase() == beacon.uuid.toLowerCase(),
      );

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
    currentCoordinates.value = math.Point<double>(centerX, centerY);

    // print('[BEACON] 📍 Weighted center: ($centerX, $centerY) from $validBeacons beacons on floor $currentFloor');

    // خطوة 3: ابحث عن أقرب node **في نفس الدور فقط**
    // هذا حل لمشكلة الإحداثيات المحلية: كل دور له نسخته الخاصة من (x,y)
    POINode? nearest;
    double minDistance = double.infinity;

    final nodesInCurrentFloor = poiList
        .where((n) => n.level == currentFloor)
        .toList();
    // print('[BEACON] 🔍 Searching in ${nodesInCurrentFloor.length} nodes on floor $currentFloor (from ${poiList.length} total)');

    for (final node in nodesInCurrentFloor) {
      final dist = math.sqrt(
        math.pow(node.x - centerX, 2) + math.pow(node.y - centerY, 2),
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = node;
      }
    }

    if (nearest != null) {
      AppLogger.debug(
        '[BEACON] ✅ Matched to: Node  ${nearest.nodeESP32ID} "${nearest.name}" (floor $currentFloor, distance: ${minDistance.toStringAsFixed(2)}m)',
      );
    }

    return nearest == null ? null : _WeightedMatch(nearest, minDistance, centerX, centerY);
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
    POINode candidate,
    double distanceToCandidate,
    int nearestRssi,
  ) {
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
      AppLogger.debug(
        '[BEACON] 🔓 تبديل القفل: من Node $_lockedNodeId إلى Node ${candidate.nodeID} '
        '(floorChanged=$floorChanged, distance=${distanceToCandidate.toStringAsFixed(2)}m, rssi=$nearestRssi)',
      );
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

    AppLogger.debug(
      '[BEACON] 🔒 محافظ على القفل عند Node $_lockedNodeId '
      '(المرشح ${candidate.nodeID} بعيد=${distanceToCandidate.toStringAsFixed(2)}m أو إشارة ضعيفة=$nearestRssi)',
    );
    return lockedNode;
  }

  /// تحديث الموقع من POINode مباشرة (بعد حساب weighted position)
  void setCurrentLocationFromNode(POINode location) {
    final navController = Get.find<NavigationController>();
    final bool isSameNode = haveCurrentLocation.value &&
        currentLocation.value.nodeID == location.nodeID;

    if (!isSameNode) {
      currentLocation.value = location;
      navController.setCurrentLocation(currentLocation.value);
      haveCurrentLocation.value = true;
    }

    cancelTimer();
    startTimer(defaultScanTimerSeconds);
  }

  /// تحديث الموقع من UUID (الطريقة القديمة — للـ fallback فقط)
  void setCurrentLocationFromUuid(String uuid) {
    final navController = Get.find<NavigationController>();
    final targetNode = poiList.firstWhereOrNull(
      (element) => element.nodeESP32ID.toLowerCase() == uuid.toLowerCase(),
    );
    if (targetNode == null) return;

    final bool isSameNode = haveCurrentLocation.value &&
        currentLocation.value.nodeID == targetNode.nodeID;

    if (!isSameNode) {
      currentLocation.value = targetNode;
      navController.setCurrentLocation(currentLocation.value);
      haveCurrentLocation.value = true;
    }

    cancelTimer();
    startTimer(defaultScanTimerSeconds);
  }

  /// فحص دوري كل 800ms:
  /// 1. إزالة أي بيكون لم يتم استقبال نبضاته خلال 3.5 ثانية (فصل النود أو الخروج من التغطية)
  /// 2. إذا فرغ طابور البيكونات بالكامل، التحول فوراً لوضع "أنت خارج نطاق التغطية"
  /// 3. كشف التقاطعات المعطلة في الجوار لتحويلها تلقائياً إلى عقد افتراضية (Virtual Fallback)
  void _checkBeaconExpirations() {
    final now = DateTime.now();

    // 1. تنظيف أي بيكون لم يتم استقبال نبضاته خلال آخر 3.5 ثوانٍ
    beaconDataPriorityQueue.removeWhere((item) {
      final diff = now.difference(item.dateTime);
      return diff >= _beaconStaleDuration;
    });

    // 2. إذا فرغ الطابور تماماً (انقطاع كل البيكونات أو فصل النود الوحيدة التي كانت تعمل):
    if (beaconDataPriorityQueue.isEmpty) {
      _filteredRssiByUuid.clear();
      currentCoordinates.value = null;

      final isNavigating = (Get.isRegistered<modern_nav.NavigationScreenController>() &&
              Get.find<modern_nav.NavigationScreenController>().isNavigating.value) ||
          (Get.isRegistered<NavigationController>() &&
              Get.find<NavigationController>().isNavigating);

      if (!isNavigating) {
        if (haveCurrentLocation.value) {
          haveCurrentLocation.value = false;
          _lockedNodeId = null;
          _lockedFloor = null;
          currentLocation.value = POINode(
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
          );
          AppLogger.debug('[BEACON] 📡 انقطعت جميع إشارات البيكون — تحول فوري لوضع خارج التغطية');
        }
      }
    } else {
      // 3. فحص وكشف عقد التقاطعات المعطلة في الجوار لتحويلها إلى عقد افتراضية
      _detectOfflineIntersectionBeacons();

      // لو كان الموقع غير محدد ولكن أصبح لدينا بيكون في الطابور
      if (!haveCurrentLocation.value) {
        _processNearestBeacons();
      }
    }
  }

  /// كشف عقد التقاطعات أو الممرات المعطلة (التي لها UUID فيزيائي مسجل لكن لا تبث إشارة)
  /// واعتمادها كعقد افتراضية (Virtual Fallback) لضمان عدم توقف الملاحة واستمرار التوجيه.
  void _detectOfflineIntersectionBeacons() {
    if (poiList.isEmpty) return;

    final visibleUuids = beaconDataPriorityQueue
        .map((b) => b.uuid.toLowerCase())
        .toSet();

    final currentFloor = currentLocation.value.level;

    for (final node in poiList) {
      if (node.level != currentFloor) continue;

      // فحص النودز التي يفترض أن تبث إشارة بيكون فيزيائي
      final hasPhysicalUuid = node.nodeESP32ID.isNotEmpty &&
          !node.nodeESP32ID.startsWith('unknown-');

      if (!hasPhysicalUuid) continue;

      final isSeen = visibleUuids.contains(node.nodeESP32ID.toLowerCase());

      if (isSeen) {
        // إذا كانت تعمل، نتأكد من إزالتها من قائمة الفيرشوال (الشفاء الذاتي Self-Healing)
        if (virtualFallbackNodes.contains(node.nodeID)) {
          virtualFallbackNodes.remove(node.nodeID);
          AppLogger.debug(
            '[BEACON] 🔄 استعادة إشارة نود التقاطع [${node.name}] (ID: ${node.nodeID}) — إلغاء وضع الفيرشوال المؤقت',
          );
        }
      } else {
        // هل نحن أو مسارنا بالقرب من هذا التقاطع بحيث يفترض التقاط إشارته؟
        bool shouldBeInRange = false;

        // 1. القرب من الإحداثيات المستمرة المرجحة
        if (currentCoordinates.value != null) {
          final dist = math.sqrt(
            math.pow(node.x - currentCoordinates.value!.x, 2) +
                math.pow(node.y - currentCoordinates.value!.y, 2),
          );
          if (dist <= 14.0) {
            shouldBeInRange = true;
          }
        }

        // 2. أو القرب من أحد جيران النود المباشرين المرئيين حالياً
        if (!shouldBeInRange) {
          for (final neighbour in node.neighbourArray) {
            final neighbourNode = poiNodes[neighbour.nodeID];
            if (neighbourNode != null &&
                visibleUuids.contains(neighbourNode.nodeESP32ID.toLowerCase())) {
              shouldBeInRange = true;
              break;
            }
          }
        }

        // 3. أو إذا كانت النود تقع مباشرة على مسار الملاحة النشط الحالي
        if (!shouldBeInRange && Get.isRegistered<modern_nav.NavigationScreenController>()) {
          final navCtrl = Get.find<modern_nav.NavigationScreenController>();
          if (navCtrl.isNavigating.value && navCtrl.isNodeOnActivePath(node.nodeID)) {
            shouldBeInRange = true;
          }
        }

        if (shouldBeInRange && !virtualFallbackNodes.contains(node.nodeID)) {
          virtualFallbackNodes.add(node.nodeID);
          AppLogger.debug(
            '[BEACON] 💡 تم اكتشاف نود تقاطع معطلة أو مفصولة [${node.name}] (ID: ${node.nodeID}) — تحويلها إلى نود افتراضية (Virtual Fallback) لضمان استمرار الملاحة بسلاسة',
          );
        }
      }
    }
  }
}
