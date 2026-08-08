package com.tranex.pathfinder

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tranex.pathfinder/bluetooth"

    // Arbitrary but fixed request code for the "turn on Bluetooth?" system
    // dialog. Only needs to be unique among startActivityForResult calls
    // made directly by this Activity (plugins register their own result
    // listeners through a separate mechanism, so this doesn't collide with
    // them).
    private val REQUEST_ENABLE_BT = 4370

    // Holds the pending Dart-side MethodChannel.Result between firing the
    // ACTION_REQUEST_ENABLE intent and onActivityResult() delivering the
    // user's answer. FlutterActivity extends android.app.Activity (not
    // androidx ComponentActivity), so the modern
    // registerForActivityResult(ActivityResultContracts...) API isn't
    // available here -- startActivityForResult/onActivityResult is the
    // correct mechanism for this class.
    private var pendingBluetoothResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestEnableBluetooth" -> {
                        if (pendingBluetoothResult != null) {
                            // A previous request is still waiting on the
                            // user; don't let a second one silently
                            // overwrite/leak the first Dart Future.
                            result.error(
                                "ALREADY_PENDING",
                                "A requestEnableBluetooth call is already in flight",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        pendingBluetoothResult = result

                        // Shows the standard Android "Allow app to turn on
                        // Bluetooth?" system dialog. Requires
                        // BLUETOOTH_CONNECT to already be granted on
                        // Android 12+ (handled by permission_handler on
                        // the Dart side before this is ever called).
                        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                        try {
                            startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
                        } catch (e: Exception) {
                            pendingBluetoothResult = null
                            result.error(
                                "REQUEST_ENABLE_FAILED",
                                e.message,
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_ENABLE_BT) {
            // resultCode is Activity.RESULT_OK if the user tapped "Allow"
            // (BluetoothAdapter mirrors that as its own RESULT_OK), or
            // Activity.RESULT_CANCELED if they tapped "Deny"/dismissed it.
            val enabled = resultCode == Activity.RESULT_OK
            pendingBluetoothResult?.success(enabled)
            pendingBluetoothResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
