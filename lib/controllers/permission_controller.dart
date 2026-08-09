import 'dart:async';

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
      print("[PERMISSION] Bluetooth Status (stream): $status");
      if (status == BleStatus.ready) {
        print("[PERMISSION] ✓ Bluetooth ready");
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
          "[PERMISSION] Location Permission: ${locationPermissionGranted.value}");
      print("[PERMISSION] Bluetooth Status: ${bluetoothStatus.value}");
      if (bluetoothPermissionsGranted && bluetoothStatus.value) {
        print("[PERMISSION] ✓ All permissions and Bluetooth ready");
      }
    } finally {
      _permissionRequestInFlight = false;
    }
  }

  /// Shows Android's native "turn on Bluetooth?" dialog. Only makes sense
  /// to call when [bleStatusRaw] is [BleStatus.poweredOff] -- i.e. the
  /// permissions are fine but the adapter itself is switched off.
  ///
  /// Waits for the user's answer and, if they allowed it, waits for
  /// flutter_reactive_ble's status stream to reflect the adapter actually
  /// coming back on before updating [bluetoothStatus]/[bleStatusRaw] --
  /// the OS dialog resolving doesn't mean the radio has finished powering
  /// up yet.
  Future<bool> requestEnableBluetooth() async {
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
