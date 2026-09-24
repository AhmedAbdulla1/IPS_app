import 'dart:io';
import 'package:flutter/services.dart';
import '../core/utils/app_logger.dart';

/// Thin wrapper around the platform channel used to show Android's native
/// "Allow app to turn on Bluetooth?" dialog (ACTION_REQUEST_ENABLE).
///
/// There's no cross-platform equivalent for this in flutter_reactive_ble
/// (or any other plugin currently in use), so this talks to
/// `MainActivity.kt` directly via a MethodChannel. See MainActivity.kt for
/// the native side of this call.
class BluetoothNative {
  BluetoothNative._();

  static const MethodChannel _channel =
      MethodChannel('com.tranex.pathfinder/bluetooth');

  /// Shows the system "turn on Bluetooth?" dialog and suspends until the
  /// user answers it.
  ///
  /// Returns:
  /// - `true` if the user allowed enabling Bluetooth,
  /// - `false` if they denied or dismissed the dialog,
  /// - `null` if the platform call itself failed (e.g. a previous request
  ///   was still pending, or the intent couldn't be started). Callers
  ///   should treat `null` the same as `false` and fall back to
  ///   re-checking the BLE status stream rather than assuming success.
  static Future<bool?> requestEnableBluetooth() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestEnableBluetooth');
    } on PlatformException catch (e) {
      AppLogger.error('requestEnableBluetooth failed', e);
      return null;
    }
  }
}
