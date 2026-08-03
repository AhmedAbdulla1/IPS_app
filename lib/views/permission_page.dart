import 'package:pathfinder/controllers/permission_controller.dart';
import 'package:pathfinder/utils/constants.dart';
import 'package:pathfinder/utils/image_constants.dart';
import 'package:pathfinder/utils/size_config.dart';
import 'package:pathfinder/utils/size_helpers.dart';
import 'package:pathfinder/views/onboarding_page.dart';
import 'package:pathfinder/views/selection_page.dart';
import 'package:pathfinder/widgets/rounded_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionPage extends StatelessWidget {
  final permissionController = Get.find<PermissionController>();

  String _buildStatusMessage() {
    final locationOk = permissionController.locationPermissionGranted.value;
    final bluetoothOk = permissionController.bluetoothStatus.value;

    if (!locationOk && !bluetoothOk) {
      return "Please allow Location permission AND turn on Bluetooth to continue";
    } else if (!locationOk) {
      return "Please allow the Location permission to continue";
    } else if (!bluetoothOk) {
      return "Bluetooth is turned off. Please turn it on to continue";
    }
    return "Please Allow / Enable The Following Permissions";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 40,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Spacer(),
                Obx(
                  () => Text(
                    _buildStatusMessage(),
                    style: TextStyle(
                      fontSize: getDefaultProportionateScreenWidth(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Spacer(),
                Image.asset(
                  gifPermission,
                ),
                Spacer(),
                Text(
                  "Restart app after enabling permission",
                  style: TextStyle(
                    fontSize: getDefaultProportionateScreenWidth(),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: displayHeight(context) * 0.02,
                ),
                RoundedButton(
                  btnColor: kSecondaryColor,
                  btnText: 'GO TO SETTINGS',
                  btnFunction: () {
                    openAppSettings();
                  },
                ),
                Obx(() {
                  // Bluetooth permission is fine but the adapter itself is
                  // switched off -- show a dedicated button that fires the
                  // native "turn on Bluetooth?" system dialog instead of
                  // sending the user to Settings (which wouldn't help here).
                  if (permissionController.bleStatusRaw.value !=
                      BleStatus.poweredOff) {
                    return SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      SizedBox(
                        height: displayHeight(context) * 0.02,
                      ),
                      RoundedButton(
                        btnColor: kPrimaryColor,
                        btnText: 'TURN ON BLUETOOTH',
                        btnFunction: () {
                          permissionController.requestEnableBluetooth();
                        },
                      ),
                    ],
                  );
                }),
                SizedBox(
                  height: displayHeight(context) * 0.02,
                ),
                RoundedButton(
                  btnColor: kPrimaryColor,
                  btnText: 'NEXT',
                  btnFunction: () async {
                    await permissionController.checkPermissionStatus();
                    if (permissionController.locationPermissionGranted.value ==
                            true &&
                        permissionController.bluetoothStatus.value == true) {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      if (prefs.getBool('initial') == true) {
                        Get.offAll(SelectionPage());
                      } else {
                        Get.offAll(OnboardingPage());
                      }
                    } else {
                      Get.rawSnackbar(
                        titleText: Text(
                          'Error',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        messageText: Text(
                          'Please allow the permissions above.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }
                  },
                ),
                Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
