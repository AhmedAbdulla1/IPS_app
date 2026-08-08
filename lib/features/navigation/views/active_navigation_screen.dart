import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/cancel_navigation_button.dart';
import '../widgets/destination_header.dart';
import '../widgets/direction_hero.dart';
import '../widgets/route_progress_panel.dart';

/// حالة الشاشة بعد بدء التوجيه — بتستجيب لمفتاح الوضع الليلي زي أي شاشة تانية:
/// الوضع الليلي (الافتراضي القديم) = زي صورة المرجع بالظبط، والوضع النهاري
/// نفس التصميم والترتيب بس بألوان فاتحة متسقة مع باقي التطبيق.
///
/// الترتيب:
/// 1) شريط علوي مضغوط (منيو + شعار + لغة)
/// 2) عنوان الوجهة الحالية ("إلى: ...") + الدور الحالي
/// 3) السهم الكبير + نص التعليمات
/// 4) بانل تقدّم المسار (حالة + ستيبر + مسافة/دور قادم)
/// 5) زرار إلغاء الملاحة
class ActiveNavigationScreen extends StatelessWidget {
  final NavigationScreenController controller;

  const ActiveNavigationScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      final palette = AppPalette.of(themeController.isDarkMode.value);

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // 2) عنوان الوجهة
              Obx(
                () => DestinationHeader(
                  destinationName: controller.selectedDestination.value?.name ?? '',
                  floorLabel: 'الدور @n'.trParams({'n': '${controller.currentFloor.value}'}),
                  palette: palette,
                ),
              ),

              const Spacer(),

              // 3) السهم + التعليمات
              Obx(
                () => DirectionHero(
                  direction: _mapDirection(controller.currentDirection.value),
                  instruction: controller.directionInstruction.value,
                  subInstruction: controller.directionSubInstruction.value,
                  palette: palette,
                ),
              ),

              const Spacer(),

              // 4) بانل تقدّم المسار
              Obx(
                () => RouteProgressPanel(
                  isOnCorrectPath: controller.isOnCorrectPath.value,
                  totalSteps: controller.totalRouteSteps.value,
                  currentStep: controller.currentRouteStep.value,
                  remainingDistanceLabel: controller.remainingDistanceLabel.value,
                  targetFloor: controller.targetFloor.value,
                  palette: palette,
                ),
              ),

              const SizedBox(height: 16),

              // 5) زرار إلغاء الملاحة
              CancelNavigationButton(onPressed: controller.endNavigation, palette: palette),

              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    });
  }

  DirectionType _mapDirection(String value) {
    switch (value) {
      case 'right':
        return DirectionType.right;
      case 'straight':
        return DirectionType.straight;
      case 'uturn':
        return DirectionType.uTurn;
      case 'left':
      default:
        return DirectionType.left;
    }
  }
}
