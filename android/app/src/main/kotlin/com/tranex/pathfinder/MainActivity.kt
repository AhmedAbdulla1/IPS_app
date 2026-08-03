package com.tranex.pathfinder

import android.bluetooth.BluetoothAdapter
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tranex.pathfinder/bluetooth"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestEnableBluetooth" -> {
                        // Shows the standard Android "Allow app to turn on
                        // Bluetooth?" system dialog. Requires
                        // BLUETOOTH_CONNECT to already be granted on
                        // Android 12+ (handled by permission_handler on
                        // the Dart side before this is ever called).
                        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                        startActivity(enableBtIntent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
