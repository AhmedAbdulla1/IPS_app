import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../controllers/app_tour_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/cancel_navigation_button.dart';
import '../widgets/destination_header.dart';
import '../widgets/direction_hero.dart';
import '../widgets/route_progress_panel.dart';

/// محتوى (Body) حالة الشاشة بعد بدء التوجيه. الـ Scaffold والـ AppBar
/// مملوكين لـ [MainNavigationScreen] اللي بيستدعي الويدجت ده — عشان يبقى
/// فيه خلفية واحدة موحّدة للشاشة كلها.
///
/// الترتيب:
/// 1) عنوان الوجهة الحالية ("إلى: ...") + الدور الحالي
/// 2) السهم الكبير + نص التعليمات
/// 3) بانل تقدّم المسار (حالة + ستيبر + مسافة/دور قادم)
/// 4) زرار إلغاء الملاحة
class ActiveNavigationScreen extends StatelessWidget {
  final NavigationScreenController controller;
  final AppPalette palette;

  const ActiveNavigationScreen({super.key, required this.controller, required this.palette});

  @override
  Widget build(BuildContext context) {
    final tourController = Get.isRegistered<AppTourController>()
        ? Get.find<AppTourController>()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // 1) عنوان الوجهة
          Container(
            key: tourController?.destinationHeaderKey,
            child: Obx(
              () => DestinationHeader(
                destination: controller.selectedDestination.value,
                floorLabel: 'الدور @n'.trParams({'n': '${controller.destinationFloor.value}'}),
                palette: palette,
              ),
            ),
          ),

          const Spacer(),

          // 2) السهم + التعليمات
          Container(
            key: tourController?.directionHeroKey,
            child: Obx(
              () => DirectionHero(
                direction: _mapDirection(controller.currentDirection.value),
                instruction: controller.directionInstruction.value,
                subInstruction: controller.directionSubInstruction.value,
                palette: palette,
              ),
            ),
          ),

          const Spacer(),

          // 3) بانل تقدّم المسار
          Container(
            key: tourController?.routeProgressKey,
            child: Obx(
              () => RouteProgressPanel(
                isOnCorrectPath: controller.isOnCorrectPath.value,
                totalSteps: controller.totalRouteSteps.value,
                currentStep: controller.currentRouteStep.value,
                remainingDistanceLabel: controller.remainingDistanceLabel.value,
                targetFloor: controller.targetFloor.value,
                palette: palette,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 4) زرار إلغاء الملاحة
          Container(
            key: tourController?.cancelButtonKey,
            child: CancelNavigationButton(onPressed: controller.endNavigation, palette: palette),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  DirectionType _mapDirection(String value) {
    switch (value) {
      case 'right':
        return DirectionType.right;
      case 'straight':
        return DirectionType.straight;
      case 'uturn':
        return DirectionType.uTurn;
      case 'up':
        return DirectionType.up;
      case 'down':
        return DirectionType.down;
      case 'arrived':
        return DirectionType.arrived;
      case 'left':
      default:
        return DirectionType.left;
    }
  }
}
