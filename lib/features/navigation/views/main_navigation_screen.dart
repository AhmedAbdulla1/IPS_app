import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../../settings/views/settings_screen.dart';
import '../../../controllers/beacon_controller.dart';
import '../controllers/navigation_controller.dart';
import 'active_navigation_screen.dart';
import 'idle_home_screen.dart';
import '../widgets/active_nav_app_bar.dart';
import '../widgets/parliament_app_bar.dart';

/// نقطة الدخول للشاشة الرئيسية — بتبدّل بين حالتين بثيمين مختلفين تمامًا:
/// - isNavigating == false → [IdleHomeScreen] (ثيم فاتح: بحث + اختصارات + موقع حالي)
/// - isNavigating == true  → [ActiveNavigationScreen] (ثيم غامق: سهم توجيه + تقدّم المسار)
class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationScreenController());

    // بدء مسح البيكونات الفعلي (BLE) بمجرد ما الشاشة الرئيسية تتبني —
    // نفس اللي كانت SelectionPage القديمة بتعمله في build() بتاعها.
    // الاستدعاء آمن يتكرر (BeaconController._isRanging بيمنع تكرار المسح).
    Get.find<BeaconController>().beaconInitPlatformState();

    return Obx(() {
      final themeController = Get.find<ThemeController>();
      final localeController = Get.find<LocaleController>();
      final palette = AppPalette.of(themeController.isDarkMode.value);

      return Scaffold(
        backgroundColor: palette.background,
        appBar: controller.isNavigating.value
            ? ActiveNavAppBar(
                palette: palette,
                onMenuTap: () => Get.to(() => const SettingsScreen()),
                onLanguageToggle: localeController.toggleLocale,
              )
            : ParliamentAppBar(
                palette: palette,
                isArabic: localeController.isArabic,
                onMenuTap: () => Get.to(() => const SettingsScreen()),
                onLanguageToggle: localeController.toggleLocale,
              ),
        body: controller.isNavigating.value
            ? ActiveNavigationScreen(controller: controller) // Will return just the body
            : IdleHomeScreen(controller: controller),       // Will return just the body
      );
    });
  }
}
