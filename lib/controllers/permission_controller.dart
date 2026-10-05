import '../core/utils/app_logger.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:flutter/widgets.dart';
import 'package:parliament_ips/utils/bluetooth_native.dart';
import 'package:parliament_ips/utils/location_native.dart';

class PermissionController extends GetxController with WidgetsBindingObserver {
  var locationPermissionGranted = false.obs;
  var locationServiceEnabled = false.obs;
  var isBluetoothAdapterOn = false.obs;
  var bluetoothStatus = false.obs;

  /// Raw status straight from flutter_reactive_ble, so the UI can tell
  /// "permission not granted" apart from "adapter is physically off" and
  /// react differently (request permission vs. offer to turn Bluetooth on).
  var bleStatusRaw = BleStatus.unknown.obs;

  // Shared instance registered once in main.dart's InitializeService --
  // do NOT construct a new FlutterReactiveBle() here. See main.dart's
  // InitializeService.init() doc comment for why a second instance broke
  // BeaconController's status reads.
  final FlutterReactiveBle _ble = Get.find<FlutterReactiveBle>();
  StreamSubscription<BleStatus>? _bleStatusSubscription;

  // Guards against firing a second Permission.request() while one is
  // already in flight. Android throws "A request for permissions is
  // already running" if two overlap, which previously crashed
  // AppRouter's _resolveStartScreen and left the app stuck on the
  // loading state forever.
  bool _permissionRequestInFlight = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // flutter_reactive_ble only starts actually reporting BleStatus once
    // something subscribes to statusStream; `_ble.status` alone stays
    // stuck at BleStatus.unknown forever otherwise.
    _bleStatusSubscription = _ble.statusStream.listen((status) {
      bleStatusRaw.value = status;
      if (status == BleStatus.ready) {
        isBluetoothAdapterOn.value = true;
        bluetoothStatus.value = true;
        locationServiceEnabled.value = true;
      } else if (status == BleStatus.locationServicesDisabled) {
        // RxAndroidBle / flutter_reactive_ble reaches locationServicesDisabled
        // ONLY if the Bluetooth adapter is already enabled!
        isBluetoothAdapterOn.value = true;
        bluetoothStatus.value = true;
        locationServiceEnabled.value = false;
      } else if (status == BleStatus.poweredOff) {
        isBluetoothAdapterOn.value = false;
        bluetoothStatus.value = false;
      } else if (status == BleStatus.unauthorized) {
        bluetoothStatus.value = false;
      }
      AppLogger.debug(
          "[PERMISSION] Bluetooth Status (stream): $status, adapterOn: ${isBluetoothAdapterOn.value}");
      if (status == BleStatus.ready) {
        AppLogger.debug("[PERMISSION] ✓ Bluetooth ready");
      }
    });
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _bleStatusSubscription?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // إعادة فحص سريعة وتلقائية بمجرد عودة المستخدم من شاشة الإعدادات
      checkPermissionStatus();
    }
  }

  Future<void> askPermission() => checkPermissionStatus();

  Future<void> checkPermissionStatus() async {
    if (_permissionRequestInFlight) return;
    _permissionRequestInFlight = true;

    try {
      final bool bluetoothPermissionsGranted;

      if (Platform.isIOS) {
        // On iOS, Bluetooth access uses CoreBluetooth (Permission.bluetooth).
        // Android-specific permissions (bluetoothScan, bluetoothConnect) do not exist on iOS.
        final statuses = await [
          Permission.location,
          Permission.bluetooth,
        ].request();

        locationPermissionGranted.value =
            statuses[Permission.location]?.isGranted ?? false;

        bluetoothPermissionsGranted =
            statuses[Permission.bluetooth]?.isGranted ?? false;
      } else {
        // Request location AND the Android 12+ runtime Bluetooth permissions
        // in a single batched call.
        final statuses = await [
          Permission.location,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();

        locationPermissionGranted.value =
            statuses[Permission.location]?.isGranted ?? false;

        bluetoothPermissionsGranted =
            (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
                (statuses[Permission.bluetoothConnect]?.isGranted ?? false);
      }

      // فحص هل خدمة الموقع (GPS) مفعّلة في الهاتف
      final serviceStatus = await Permission.location.serviceStatus;
      locationServiceEnabled.value =
          serviceStatus.isEnabled || serviceStatus == ServiceStatus.notApplicable;
      AppLogger.debug(
          "[PERMISSION] Location Service (GPS): ${locationServiceEnabled.value} ($serviceStatus)");

      // فحص هل محول البلوتوث الفيزيائي يعمل في الهاتف اعتماداً على حالة Reactive BLE
      final currentBle = _ble.status;
      if (currentBle == BleStatus.ready ||
          currentBle == BleStatus.locationServicesDisabled) {
        isBluetoothAdapterOn.value = true;
      } else if (currentBle == BleStatus.poweredOff) {
        isBluetoothAdapterOn.value = false;
      }

      if (!bluetoothPermissionsGranted) {
        bluetoothStatus.value = false;
      } else {
        bluetoothStatus.value = isBluetoothAdapterOn.value;
      }

      AppLogger.debug(
          "[PERMISSION] Location Permission: ${locationPermissionGranted.value}");
      AppLogger.debug(
          "[PERMISSION] Bluetooth Adapter: ${isBluetoothAdapterOn.value}, Bluetooth Status: ${bluetoothStatus.value}");
      if (bluetoothPermissionsGranted && isBluetoothAdapterOn.value && locationServiceEnabled.value) {
        AppLogger.debug("[PERMISSION] ✓ All permissions, GPS, and Bluetooth ready");
      }
    } finally {
      _permissionRequestInFlight = false;
    }
  }

  /// Shows the system dialog or opens settings to enable Bluetooth.
  /// On iOS, apps cannot programmatically toggle Bluetooth, so settings is opened.
  Future<bool> requestEnableBluetooth() async {
    if (Platform.isIOS) {
      await openAppSettings();
      return isBluetoothAdapterOn.value;
    }

    final userAllowed = await BluetoothNative.requestEnableBluetooth();
    if (userAllowed != true) return false;

    isBluetoothAdapterOn.value = true;
    bluetoothStatus.value = true;
    await Future.delayed(const Duration(milliseconds: 300));
    await checkPermissionStatus();
    return isBluetoothAdapterOn.value;
  }

  /// يفتح صفحة إعدادات الموقع لتفعيل الـ GPS
  Future<bool> requestEnableLocation() async {
    await LocationNative.requestEnableLocation();
    await Future.delayed(const Duration(milliseconds: 500));
    await checkPermissionStatus();
    return locationServiceEnabled.value;
  }
}

