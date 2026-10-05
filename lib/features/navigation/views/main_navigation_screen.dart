import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../../settings/views/settings_screen.dart';
import '../../../controllers/beacon_controller.dart';
import '../controllers/app_tour_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/tour/app_tour_overlay.dart';
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
  late final AppTourController tourController;

  @override
  void initState() {
    super.initState();
    controller = Get.put(NavigationScreenController());
    tourController = Get.put(AppTourController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Get.find<BeaconController>().beaconInitPlatformState();
        if (!controller.isNavigating.value) {
          tourController.checkAndStartIdleTour();
        } else {
          tourController.checkAndStartActiveTour();
        }
      }
    });

    // استماع لتغير حالة بدء الملاحة لإطلاق جولة الملاحة النشطة فوراً
    ever(controller.isNavigating, (bool isNavigating) {
      if (isNavigating) {
        tourController.checkAndStartActiveTour();
      } else {
        if (tourController.isTourActive.value &&
            tourController.currentTourMode.value == TourMode.active) {
          tourController.isTourActive.value = false;
        }
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
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: Colors.transparent,
                  // مهم: من غير كده، فتح الكيبورد وقت الكتابة في شريط البحث بيخلي
                  // فليتر يقلل ارتفاع الـ body، وعناصر IdleHomeScreen الثابتة
                  // (حقل البحث + الاختصارات + بانل الموقع + صف الحالة + زرار
                  // البدء) بتتخطى المساحة المتبقية → RenderFlex overflow، حتى لو
                  // الدروب داون قافل أصلاً. القائمة نفسها بتتعرض عن طريق Overlay
                  // طايف مربوط بموضع الحقل مباشرة (مش بموضع الـ body)، فمش
                  // محتاجة الـ Scaffold يعمل resize أصلاً عشانها.
                  resizeToAvoidBottomInset: false,
                  appBar: ParliamentAppBar(
                    palette: palette,
                    isArabic: localeController.isArabic,
                    onMenuTap: () => Get.to(() => const SettingsScreen()),
                    onLanguageToggle: localeController.toggleLocale,
                    onTourTap: () {
                      if (controller.isNavigating.value) {
                        tourController.startTour(
                          mode: TourMode.active,
                          force: true,
                        );
                      } else {
                        tourController.startTour(
                          mode: TourMode.idle,
                          force: true,
                        );
                      }
                    },
                    tourKey: tourController.appBarKey,
                  ),
                  body: controller.isNavigating.value
                      ? ActiveNavigationScreen(controller: controller, palette: palette)
                      : IdleHomeScreen(
                          controller: controller,
                          palette: palette,
                        ),
                ),

                // طبقة الجولة التعريفية التراكبية (App Tour)
                Obx(() {
                  if (!tourController.isTourActive.value) {
                    return const SizedBox.shrink();
                  }
                  return AppTourOverlay(
                    controller: tourController,
                    palette: palette,
                    isArabic: localeController.isArabic,
                  );
                }),
              ],
            ),
          ),
        ),
      );
    });
  }
}
