import '../core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:get/get.dart';
import 'permission_controller.dart';

class CompassController extends GetxController {
  final heading = 0.0.obs;
  final accuracy = 'Unknown'.obs;
  double? currentBearingSnapshot;
  double? locationBearingSnapshot;
  StreamSubscription<CompassEvent>? _compassSubscription;

  String get readout => heading.toStringAsFixed(0) + '°';

  @override
  void onInit() {
    super.onInit();
    _initCompass();

    // مهم لنظام iOS: لا تبدأ CoreLocation بتسليم زوايا Heading إلا بعد
    // الحصول على إذن الموقع الفعلي، لذا نعيد الاشتراك فور منح الصلاحية
    if (Get.isRegistered<PermissionController>()) {
      final permController = Get.find<PermissionController>();
      ever(permController.locationPermissionGranted, (granted) {
        if (granted) {
          AppLogger.debug('[COMPASS] Location permission granted — re-initializing compass stream for iOS/Android');
          _initCompass();
        }
      });
    }
  }

  void _initCompass() {
    _compassSubscription?.cancel();
    try {
      _compassSubscription = FlutterCompass.events?.listen(
        _onData,
        onError: (err) {
          AppLogger.debug('[COMPASS] Sensor error: $err');
        },
      );
    } catch (e) {
      AppLogger.debug('[COMPASS] Exception starting compass: $e');
    }
  }

  void _onData(CompassEvent compassEvent) {
    final rawHeading = compassEvent.heading;
    if (rawHeading == null) return;

    // تصفية وتنعيم قراءات البوصلة (Low-pass filter with modular wrap-around)
    if (heading.value == 0.0) {
      heading.value = rawHeading;
    } else {
      double diff = (rawHeading - heading.value + 180) % 360 - 180;
      double smoothed = (heading.value + diff * 0.25) % 360;
      if (smoothed < 0) smoothed += 360;
      heading.value = smoothed;
    }

    if (compassEvent.accuracy == 15.0) {
      accuracy.value = 'High';
    } else if (compassEvent.accuracy == 30.0) {
      accuracy.value = 'Medium';
    } else if (compassEvent.accuracy == 45.0) {
      accuracy.value = 'Low';
    } else {
      accuracy.value = 'Unknown';
    }
  }

  @override
  void onClose() {
    _compassSubscription?.cancel();
    super.onClose();
  }
}
