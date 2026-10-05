import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parliament_ips/features/navigation/controllers/app_tour_controller.dart';
import 'package:parliament_ips/features/navigation/widgets/tour/app_tour_overlay.dart';
import 'package:parliament_ips/core/theme/app_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
  });

  group('AppTourController Tests', () {
    test('Initializes with 6 idle steps and 4 active steps', () {
      final controller = AppTourController();
      controller.onInit();

      expect(controller.idleSteps.length, 6);
      expect(controller.activeSteps.length, 4);

      expect(controller.idleSteps[0].id, 'search_bar');
      expect(controller.activeSteps[0].id, 'destination_header');
      expect(controller.activeSteps[1].id, 'direction_hero');
      expect(controller.activeSteps[2].id, 'route_progress');
      expect(controller.activeSteps[3].id, 'cancel_button');

      expect(controller.isTourActive.value, false);
      expect(controller.currentStep.value, 0);
    });

    test('All steps have valid Arabic and English titles and descriptions', () {
      final controller = AppTourController();
      controller.onInit();

      for (final step in [...controller.idleSteps, ...controller.activeSteps]) {
        expect(step.titleAr.isNotEmpty, true);
        expect(step.titleEn.isNotEmpty, true);
        expect(step.descriptionAr.isNotEmpty, true);
        expect(step.descriptionEn.isNotEmpty, true);
      }
    });

    testWidgets('Calculates relative local coordinates with ancestor correctly', (tester) async {
      final controller = AppTourController();
      controller.onInit();

      final GlobalKey ancestorKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 50.0, left: 20.0),
              child: Container(
                key: ancestorKey,
                width: 300,
                height: 400,
                child: Padding(
                  padding: const EdgeInsets.only(top: 30.0, left: 10.0),
                  child: Container(
                    key: controller.searchBarKey,
                    width: 200,
                    height: 50,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final ancestorBox = ancestorKey.currentContext?.findRenderObject() as RenderBox?;
      final rect = controller.getTargetRect(controller.searchBarKey, ancestor: ancestorBox);

      expect(rect, isNotNull);
      // Local offset inside ancestor should be top = 30 - pad, left = 10 - pad
      expect(rect!.left, lessThanOrEqualTo(10.0));
      expect(rect.top, lessThanOrEqualTo(30.0));
    });

    testWidgets('Active Navigation tour flow runs all 4 steps successfully', (tester) async {
      final controller = AppTourController();
      controller.onInit();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(key: controller.destinationHeaderKey, width: 100, height: 40),
                SizedBox(key: controller.directionHeroKey, width: 100, height: 40),
                SizedBox(key: controller.routeProgressKey, width: 100, height: 40),
                SizedBox(key: controller.cancelButtonKey, width: 100, height: 40),
              ],
            ),
          ),
        ),
      );

      await controller.startTour(mode: TourMode.active, force: true);
      expect(controller.isTourActive.value, true);
      expect(controller.currentTourMode.value, TourMode.active);
      expect(controller.currentStep.value, 0);

      controller.nextStep();
      expect(controller.currentStep.value, 1);

      controller.nextStep();
      expect(controller.currentStep.value, 2);

      controller.nextStep();
      expect(controller.currentStep.value, 3);

      await controller.completeTour();
      expect(controller.isTourActive.value, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppTourController.activeTourVersionKey), true);
    });

    testWidgets('Auto-skip fallback when an intermediate target is missing', (tester) async {
      final controller = AppTourController();
      controller.onInit();

      // Mount step 0 and step 2, but NOT step 1
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(key: controller.searchBarKey, width: 100, height: 40),
                // shortcutsRowKey (step 1) is missing
                SizedBox(key: controller.locationPanelKey, width: 100, height: 40),
              ],
            ),
          ),
        ),
      );

      await controller.startTour(mode: TourMode.idle, force: true);
      expect(controller.currentStep.value, 0);

      controller.nextStep();
      expect(controller.currentStep.value, 2);
    });
  });

  group('AppTourOverlay Widget Tests', () {
    testWidgets('Renders tooltip card and controls properly', (tester) async {
      final controller = Get.put(AppTourController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: SizedBox(
                    key: controller.searchBarKey,
                    width: 250,
                    height: 50,
                  ),
                ),
                AppTourOverlay(
                  controller: controller,
                  palette: AppPalette.light,
                  isArabic: true,
                ),
              ],
            ),
          ),
        ),
      );

      await controller.startTour(mode: TourMode.idle, force: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(controller.isTourActive.value, true);
      expect(find.byType(AppTourOverlay), findsOneWidget);
      expect(find.text('البحث الذكي عن الوجهات'), findsOneWidget);
      expect(find.text('تخطي'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);
    });
  });
}
