import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import '../../../../controllers/beacon_controller.dart';
import '../../../../controllers/compass_controller.dart';
import '../controllers/navigation_controller.dart';
import '../../../core/utils/app_logger.dart';

/// عينة تيليميتري لحظية واحدة تم التقاطها من قراءات النواة
class TelemetrySample {
  final DateTime timestamp;
  final double? userX;
  final double? userY;
  final int? lockedNodeId;
  final String? lockedNodeName;
  final int? floor;
  final String? nearestBeaconUuid;
  final double? filteredRssi;
  final double deviceHeading;
  final String compassAccuracy;
  final double targetHeading;
  final double relativeAngle;
  final String deadbandDecision;
  final String instruction;
  final int currentStepIndex;
  final int totalSteps;
  final int? targetNodeId;
  final double? targetNodeX;
  final double? targetNodeY;
  final String remainingDistance;
  final int offPathCounter;
  final bool isOnCorrectPath;

  const TelemetrySample({
    required this.timestamp,
    this.userX,
    this.userY,
    this.lockedNodeId,
    this.lockedNodeName,
    this.floor,
    this.nearestBeaconUuid,
    this.filteredRssi,
    required this.deviceHeading,
    required this.compassAccuracy,
    required this.targetHeading,
    required this.relativeAngle,
    required this.deadbandDecision,
    required this.instruction,
    required this.currentStepIndex,
    required this.totalSteps,
    this.targetNodeId,
    this.targetNodeX,
    this.targetNodeY,
    required this.remainingDistance,
    required this.offPathCounter,
    required this.isOnCorrectPath,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'user_coords': (userX != null && userY != null)
            ? {'x': double.parse(userX!.toStringAsFixed(2)), 'y': double.parse(userY!.toStringAsFixed(2))}
            : null,
        'locked_node': {
          'id': lockedNodeId,
          'name': lockedNodeName ?? '',
          'floor': floor,
        },
        'nearest_beacon': {
          'uuid': nearestBeaconUuid ?? '',
          'filtered_rssi': filteredRssi != null ? double.parse(filteredRssi!.toStringAsFixed(1)) : null,
        },
        'heading': {
          'device_heading': double.parse(deviceHeading.toStringAsFixed(1)),
          'target_heading': double.parse(targetHeading.toStringAsFixed(1)),
          'relative_angle': double.parse(relativeAngle.toStringAsFixed(1)),
          'compass_accuracy': compassAccuracy,
          'deadband_decision': deadbandDecision,
        },
        'guidance': {
          'current_step': currentStepIndex,
          'total_steps': totalSteps,
          'target_node_id': targetNodeId,
          'target_coords': (targetNodeX != null && targetNodeY != null)
              ? {'x': double.parse(targetNodeX!.toStringAsFixed(2)), 'y': double.parse(targetNodeY!.toStringAsFixed(2))}
              : null,
          'instruction': instruction,
          'remaining_distance': remainingDistance,
          'off_path_counter': offPathCounter,
          'is_on_correct_path': isOnCorrectPath,
        },
      };
}

/// خدمة تيليميتري مستقلة تماماً عن دورة حياة الـ UI
/// تستمع للكنترولرز وتسجل العينات كل 300ms باستهلاك مباشر للقيم المحسوبة مسبقاً
class NavigationTelemetryRecorder extends GetxService {
  Timer? _sampleTimer;
  final RxList<TelemetrySample> samples = <TelemetrySample>[].obs;
  final RxBool isRecording = false.obs;
  final RxString currentSessionId = ''.obs;

  DateTime? _navigationStartTime;
  DateTime? _navigationEndTime;

  static const int sampleIntervalMs = 300;

  @override
  void onInit() {
    super.onInit();
    AppLogger.info('[TelemetryRecorder] Service initialized.');
    _bindNavigationState();
  }

  void _bindNavigationState() {
    // ننتظر أو نتحقق من وجود NavigationScreenController
    if (Get.isRegistered<NavigationScreenController>()) {
      final navController = Get.find<NavigationScreenController>();
      ever(navController.isNavigating, (bool isNavigating) {
        if (isNavigating) {
          startSession();
        } else {
          stopSession();
        }
      });
    }
  }

  /// ربط صريح في حال تم تسجيل NavigationScreenController لاحقاً
  void attachNavigationController(NavigationScreenController navController) {
    ever(navController.isNavigating, (bool isNavigating) {
      if (isNavigating) {
        startSession();
      } else {
        stopSession();
      }
    });
  }

  void startSession() {
    if (isRecording.value) return;

    final now = DateTime.now();
    _navigationStartTime = now;
    _navigationEndTime = null;
    currentSessionId.value = 'session_${now.millisecondsSinceEpoch}';
    samples.clear();
    isRecording.value = true;

    AppLogger.info('[TelemetryRecorder] 🔴 Started session: ${currentSessionId.value}');

    _sampleTimer?.cancel();
    _sampleTimer = Timer.periodic(const Duration(milliseconds: sampleIntervalMs), (_) {
      _captureSample();
    });
  }

  void stopSession() {
    if (!isRecording.value) return;

    _sampleTimer?.cancel();
    _sampleTimer = null;
    _navigationEndTime = DateTime.now();
    isRecording.value = false;

    AppLogger.info('[TelemetryRecorder] ⏹️ Stopped session: ${currentSessionId.value} with ${samples.length} samples.');
  }

  /// التقاط عينة تيليميتري واستهلاك القيم المحسوبة مسبقاً من النواة
  void _captureSample() {
    try {
      if (!Get.isRegistered<NavigationScreenController>() ||
          !Get.isRegistered<BeaconController>() ||
          !Get.isRegistered<CompassController>()) {
        return;
      }

      final navController = Get.find<NavigationScreenController>();
      final beaconController = Get.find<BeaconController>();
      final compassController = Get.find<CompassController>();

      final userCoords = beaconController.currentCoordinates.value;
      final lockedNode = beaconController.currentLocation.value;

      // العثور على أقرب بيكون و RSSI المفلتر
      String? nearestUuid;
      double? bestRssi;
      final rssiMap = beaconController.filteredRssiByUuid;
      if (rssiMap.isNotEmpty) {
        for (final entry in rssiMap.entries) {
          if (bestRssi == null || entry.value > bestRssi) {
            bestRssi = entry.value;
            nearestUuid = entry.key;
          }
        }
      }

      // النود المستهدف الحالي في المسار
      int? targetNodeId;
      double? targetNodeX;
      double? targetNodeY;
      if (navController.currentPath.isNotEmpty &&
          navController.currentStepIndex < navController.currentPath.length) {
        final step = navController.currentPath[navController.currentStepIndex];
        targetNodeId = step.nodeId;
        final graph = navController.navigationRepository.cachedGraph;
        final targetNode = graph?.nodeById(step.nodeId);
        if (targetNode != null) {
          targetNodeX = targetNode.x;
          targetNodeY = targetNode.y;
        }
      }

      final sample = TelemetrySample(
        timestamp: DateTime.now(),
        userX: userCoords?.x,
        userY: userCoords?.y,
        lockedNodeId: lockedNode.nodeID,
        lockedNodeName: lockedNode.name,
        floor: lockedNode.level,
        nearestBeaconUuid: nearestUuid,
        filteredRssi: bestRssi,
        deviceHeading: compassController.heading.value,
        compassAccuracy: compassController.accuracy.value,
        // استهلاك مباشر للقيم المحسوبة مسبقاً من Navigation Core دون أي إعادة حساب
        targetHeading: navController.targetStepHeading.value,
        relativeAngle: navController.currentRelativeAngle.value,
        deadbandDecision: navController.currentDirection.value,
        instruction: navController.directionInstruction.value,
        currentStepIndex: navController.currentStepIndex,
        totalSteps: navController.totalRouteSteps.value,
        targetNodeId: targetNodeId,
        targetNodeX: targetNodeX,
        targetNodeY: targetNodeY,
        remainingDistance: navController.remainingDistanceLabel.value,
        offPathCounter: navController.consecutiveOffPathReadings,
        isOnCorrectPath: navController.isOnCorrectPath.value,
      );

      samples.add(sample);
    } catch (e) {
      AppLogger.warn('[TelemetryRecorder] Error capturing sample: $e');
    }
  }

  /// تصدير كامل بيانات الجلسة والميتاداتا كـ JSON
  Map<String, dynamic> exportSessionAsJson() {
    return {
      'metadata': {
        'app_version': '1.0.0',
        'build_number': '3',
        'flavor': 'test',
        'device_model': Platform.localHostname,
        'os_version': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'session_id': currentSessionId.value,
        'sample_interval_ms': sampleIntervalMs,
        'navigation_start': _navigationStartTime?.toIso8601String(),
        'navigation_end': _navigationEndTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'duration_seconds': _navigationStartTime != null
            ? (_navigationEndTime ?? DateTime.now()).difference(_navigationStartTime!).inSeconds
            : 0,
        'total_samples': samples.length,
      },
      'samples': samples.map((s) => s.toJson()).toList(),
    };
  }

  String exportSessionAsJsonString() {
    return const JsonEncoder.withIndent('  ').convert(exportSessionAsJson());
  }

  @override
  void onClose() {
    _sampleTimer?.cancel();
    super.onClose();
  }
}
