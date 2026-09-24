import '../core/utils/app_logger.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:pathfinder/utils/bluetooth_native.dart';

class PermissionController extends GetxController {
  var locationPermissionGranted = false.obs;
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

    // flutter_reactive_ble only starts actually reporting BleStatus once
    // something subscribes to statusStream; `_ble.status` alone stays
    // stuck at BleStatus.unknown forever otherwise.
    _bleStatusSubscription = _ble.statusStream.listen((status) {
      bluetoothStatus.value = status == BleStatus.ready;
      bleStatusRaw.value = status;
      AppLogger.debug("[PERMISSION] Bluetooth Status (stream): $status");
      if (status == BleStatus.ready) {
        AppLogger.debug("[PERMISSION] ✓ Bluetooth ready");
      }
    });

    // NOTE: checkPermissionStatus() is intentionally NOT called here.
    // AppRouter._resolveStartScreen() calls it once, right when the widget
    // tree is ready. Calling it a second time here (this early, before any
    // Activity/widget is attached) races against that call and can cause
    // Android to reject the second concurrent permission request.
  }

  @override
  void onClose() {
    _bleStatusSubscription?.cancel();
    super.onClose();
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

      if (!bluetoothPermissionsGranted) {
        bluetoothStatus.value = false;
      } else {
        // `_ble.status` can still read BleStatus.unknown for a brief moment
        // right after permissions are granted, which used to silently
        // overwrite a correct value from the stream listener above. Wait
        // for the first real (non-unknown) status here instead.
        final status = await _ble.statusStream
            .firstWhere((s) => s != BleStatus.unknown)
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => _ble.status,
            );
        bleStatusRaw.value = status;
        bluetoothStatus.value = status == BleStatus.ready;
      }

      AppLogger.debug(
          "[PERMISSION] Location Permission: ${locationPermissionGranted.value}");
      AppLogger.debug("[PERMISSION] Bluetooth Status: ${bluetoothStatus.value}");
      if (bluetoothPermissionsGranted && bluetoothStatus.value) {
        AppLogger.debug("[PERMISSION] ✓ All permissions and Bluetooth ready");
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
      return bluetoothStatus.value;
    }

    final userAllowed = await BluetoothNative.requestEnableBluetooth();
    if (userAllowed != true) return false;

    final status = await _ble.statusStream
        .firstWhere((s) => s != BleStatus.poweredOff && s != BleStatus.unknown)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => _ble.status,
        );
    bleStatusRaw.value = status;
    bluetoothStatus.value = status == BleStatus.ready;
    return bluetoothStatus.value;
  }
}

