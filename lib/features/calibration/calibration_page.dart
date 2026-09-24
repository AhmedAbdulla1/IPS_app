import 'package:parliament_ips/controllers/compass_controller.dart';
import 'package:parliament_ips/core/constants/app_assets.dart';
import 'package:parliament_ips/core/localization/locale_controller.dart';
import 'package:parliament_ips/core/theme/app_colors.dart';
import 'package:parliament_ips/core/theme/theme_controller.dart';
import 'package:parliament_ips/features/navigation/views/main_navigation_screen.dart';
import 'package:parliament_ips/utils/constants.dart';
import 'package:parliament_ips/utils/size_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalibrationPage extends StatelessWidget {
  CalibrationPage({super.key, required this.caliType});

  final compassController = Get.find<CompassController>();
  final CaliType caliType;

  final LocaleController localeController = Get.find<LocaleController>();
  final ThemeController themeController = Get.find<ThemeController>();

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('initial', true);
    Get.offAll(() => const MainNavigationScreen());
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final bool isArabic = localeController.isArabic;
    final bool isDark = themeController.isDarkMode.value;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDark ? AppAssets.backgroundDark : AppAssets.backgroundLight,
            ),
            fit: BoxFit.cover,
          ),
        ),

        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Text(
                isArabic ? 'اضبط البوصلة' : 'Calibrate Your Compass',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textOnDark
                      : AppColors.brownDark,
                ),
              ),

              const SizedBox(height: 15),

              // DESCRIPTION
              Text(
                isArabic
                    ? 'حرك هاتفك في شكل رقم 8 \nللحصول على قراءات دقيقة للاتجاهات'
                    : 'Move your phone in a figure-eight\n motion for accurate direction readings.',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),

              const Spacer(),

              // IMAGE
              Image.asset(
                AppAssets.onboarding3,
                fit: BoxFit.contain,
              ),

              const Spacer(),

              // =========================
              // FIXED BOTTOM CONTROLS
              // =========================
              _buildAccuracyRow(isArabic, isDark),
              Padding(
                padding: const EdgeInsets.symmetric(vertical:  15,horizontal:  20),
                child: _buildButton(isArabic),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccuracyRow(bool isArabic, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isArabic ? 'دقة البوصلة:' : 'Compass Accuracy:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Obx(
          () => Text(
            compassController.accuracy.value,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark? AppColors.textOnDark: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(bool isArabic) {
    final bool isOnboard = caliType == CaliType.onboard;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brownDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          if (isOnboard) {
            _completeOnboarding();
          } else {
            Get.back();
          }
        },
        child: Text(
          isOnboard
              ? (isArabic ? 'ابدأ' : 'Get Started')
              : (isArabic ? 'رجوع' : 'Back'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
