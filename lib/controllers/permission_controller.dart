import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/state_manager.dart';
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

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<BleStatus>? _bleStatusSubscription;

  // Guards against firing a second Permission.request() while one is
  // already in flight. Android throws "A request for permissions is
  // already running" if two overlap, which previously crashed
  // SplashScreenPage's screenFunction and left the app stuck on the
  // splash screen forever.
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
      print("Bluetooth Status (stream): $status");
    });

    // NOTE: checkPermissionStatus() is intentionally NOT called here.
    // SplashScreenPage already calls it once, right when the widget tree
    // is ready. Calling it a second time here (this early, before any
    // Activity/widget is attached) raced against that call and caused
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
      // Request location AND the Android 12+ runtime Bluetooth permissions
      // in a single batched call. Location alone is not enough for BLE
      // scanning on modern Android -- BLUETOOTH_SCAN/BLUETOOTH_CONNECT are
      // separate runtime permissions (already declared in the manifest,
      // but they still have to be requested, not just declared).
      // Batching them also avoids ever firing two separate native
      // permission requests back to back.
      final statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      locationPermissionGranted.value =
          statuses[Permission.location]?.isGranted ?? false;

      final bluetoothPermissionsGranted =
          (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
              (statuses[Permission.bluetoothConnect]?.isGranted ?? false);

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

      print(
          "Permission Status: " + locationPermissionGranted.value.toString());
      print("Bluetooth Status: " + bluetoothStatus.value.toString());
    } finally {
      _permissionRequestInFlight = false;
    }
  }

  /// Shows Android's native "turn on Bluetooth?" dialog. Only makes sense
  /// to call when [bleStatusRaw] is [BleStatus.poweredOff] -- i.e. the
  /// permissions are fine but the adapter itself is switched off.
  Future<void> requestEnableBluetooth() async {
    await BluetoothNative.requestEnableBluetooth();
  }
}
