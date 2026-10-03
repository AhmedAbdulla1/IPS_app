import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../../settings/views/settings_screen.dart';
import '../../../controllers/beacon_controller.dart';
import '../controllers/navigation_controller.dart';
import 'active_navigation_screen.dart';
import 'idle_home_screen.dart';
import '../widgets/parliament_app_bar.dart';

/// نقطة الدخول للشاشة الرئيسية — بتملك Scaffold واحد وخلفية واحدة موحّدة
/// (صورة بتتغيّر حسب الوضع الليلي/النهاري) وبتبدّل بينها وبين الـ AppBar
/// والـ body المناسبين حسب حالة التوجيه:
/// - isNavigating == false → [IdleHomeScreen]
/// - isNavigating == true  → [ActiveNavigationScreen]
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final NavigationScreenController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(NavigationScreenController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Get.find<BeaconController>().beaconInitPlatformState();
      }
    });
  }

  @override
  Widget build(BuildContext context) {

    return Obx(() {
      final themeController = Get.find<ThemeController>();
      final localeController = Get.find<LocaleController>();
      final isDark = themeController.isDarkMode.value;
      final palette = AppPalette.of(isDark);

      return SafeArea(
        child: Directionality(
          textDirection: localeController.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(isDark ? AppAssets.backgroundDark : AppAssets.backgroundLight),
                fit: BoxFit.fill,
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              // مهم: من غير كده، فتح الكيبورد وقت الكتابة في شريط البحث بيخلي
              // فليتر يقلل ارتفاع الـ body، وعناصر IdleHomeScreen الثابتة
              // (حقل البحث + الاختصارات + بانل الموقع + صف الحالة + زرار
              // البدء) بتتخطى المساحة المتبقية → RenderFlex overflow، حتى لو
              // الدروب داون قافل أصلاً. القائمة نفسها بتتعرض عن طريق Overlay
              // طايف مربوط بموضع الحقل مباشرة (مش بموضع الـ body)، فمش
              // محتاجة الـ Scaffold يعمل resize أصلاً عشانها.
              resizeToAvoidBottomInset: false,
              appBar:
                   ParliamentAppBar(
                      palette: palette,
                      isArabic: localeController.isArabic,
                      onMenuTap: () => Get.to(() => const SettingsScreen()),
                      onLanguageToggle: localeController.toggleLocale,
                    ),
              body: controller.isNavigating.value
                  ? ActiveNavigationScreen(controller: controller, palette: palette)
                  : IdleHomeScreen(
                      controller: controller,
                      palette: palette,
                      // isArabic: localeController.isArabic,
                    ),
            ),
          ),
        ),
      );
    });
  }
}
