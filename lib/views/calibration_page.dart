import 'package:pathfinder/controllers/compass_controller.dart';
import 'package:pathfinder/features/navigation/views/main_navigation_screen.dart';
import 'package:pathfinder/utils/constants.dart';
import 'package:pathfinder/utils/image_constants.dart';
import 'package:pathfinder/utils/size_config.dart';
import 'package:pathfinder/utils/size_helpers.dart';
import 'package:pathfinder/widgets/rounded_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalibrationPage extends StatelessWidget {
  CalibrationPage({ required this.caliType});

  final compassController = Get.find<CompassController>();
  final CaliType caliType;

  // final imageController = Get.find<ImageController>();
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 40,
          ),
          child: Center(
            child: Column(
              children: [
                Spacer(),
                Text(
                  "Pathfinder",
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: getDefaultProportionateScreenWidth(),
                  ),
                ),
                Spacer(),
                Text(
                  'Before we start, let’s calibrate your compass!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: getDefaultProportionateScreenWidth(),
                  ),
                ),
                SizedBox(
                  height: displayHeight(context) * 0.02,
                ),
                Text(
                  'Calibrate at anytime! Tilt and move your phone 3 times as shown!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: getDefaultProportionateScreenWidth(),
                  ),
                ),
                Image.asset(
                  gifCalibrate,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      'Compass Accuracy:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: getDefaultProportionateScreenWidth(),
                      ),
                    ),
                    Obx(
                      () => Text(
                        compassController.accuracy.value,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: getDefaultProportionateScreenWidth(),
                          color: kPrimaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: displayHeight(context) * 0.02,
                ),
                caliType == CaliType.onboard
                    ? RoundedButton(
                        btnColor: kPrimaryColor,
                        btnText: 'CONTINUE',
                        btnFunction: () async {
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          prefs.setBool('initial', true);
                          // الصفحة الرئيسية الجديدة (features/navigation) — بديل SelectionPage القديمة
                          Get.offAll(const MainNavigationScreen());
                        },
                      )
                    : RoundedButton(
                        btnColor: kPrimaryColor,
                        btnText: 'BACK',
                        btnFunction: () {
                          Get.back();
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
