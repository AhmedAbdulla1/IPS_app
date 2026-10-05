import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../models/app_tour_step.dart';

/// أوضاع الجولة التعريفية (الشاشة الرئيسية أو شاشة الملاحة النشطة)
enum TourMode { idle, active }

/// متحكم الجولة التعريفية للتطبيق (App Tour)
///
/// يدير حالة وخطوات الجولة التعريفية للشاشة الرئيسية ولشاشة الملاحة الحية
/// بدون أي حزم خارجية أو Native Code لضمان التوافق التام مع تحديثات Shorebird Over-The-Air (Patch).
class AppTourController extends GetxController {
  static const String idleTourVersionKey = 'has_seen_app_tour_v1';
  static const String activeTourVersionKey = 'has_seen_active_tour_v1';

  // مفاتيح العناصر المستهدفة بالشاشة الرئيسية (IdleHomeScreen)
  final GlobalKey searchBarKey = GlobalKey(debugLabel: 'tour_search_bar');
  final GlobalKey shortcutsRowKey = GlobalKey(debugLabel: 'tour_shortcuts_row');
  final GlobalKey locationPanelKey = GlobalKey(debugLabel: 'tour_location_panel');
  final GlobalKey floorBadgeKey = GlobalKey(debugLabel: 'tour_floor_badge');
  final GlobalKey startButtonKey = GlobalKey(debugLabel: 'tour_start_button');
  final GlobalKey appBarKey = GlobalKey(debugLabel: 'tour_app_bar');

  // مفاتيح العناصر المستهدفة بشاشة الملاحة الحية (ActiveNavigationScreen)
  final GlobalKey destinationHeaderKey =
      GlobalKey(debugLabel: 'tour_destination_header');
  final GlobalKey directionHeroKey =
      GlobalKey(debugLabel: 'tour_direction_hero');
  final GlobalKey routeProgressKey =
      GlobalKey(debugLabel: 'tour_route_progress');
  final GlobalKey cancelButtonKey =
      GlobalKey(debugLabel: 'tour_cancel_button');

  final Rx<TourMode> currentTourMode = TourMode.idle.obs;
  final RxInt currentStep = 0.obs;
  final RxBool isTourActive = false.obs;

  late final List<AppTourStep> idleSteps;
  late final List<AppTourStep> activeSteps;

  List<AppTourStep> get currentSteps =>
      currentTourMode.value == TourMode.idle ? idleSteps : activeSteps;

  @override
  void onInit() {
    super.onInit();
    _initSteps();
  }

  void _initSteps() {
    // 1) خطوات الشاشة الرئيسية
    idleSteps = [
      AppTourStep(
        id: 'search_bar',
        key: searchBarKey,
        titleAr: 'البحث الذكي عن الوجهات',
        titleEn: 'Smart Destination Search',
        descriptionAr:
            'ابحث بالاسم عن القاعات والمكاتب، أو تصفح القائمة لاختيار وجهتك.',
        descriptionEn:
            'Search for halls and offices by name, or browse the list to choose your destination.',
        borderRadius: 16.0,
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      ),
      AppTourStep(
        id: 'shortcuts_row',
        key: shortcutsRowKey,
        titleAr: 'الوصول السريع للمرافق',
        titleEn: 'Quick Facility Shortcuts',
        descriptionAr:
            'أزرار سريعة للوصول المباشر لأهم المرافق (دورات المياه والمصاعد) بنقرة واحدة.',
        descriptionEn:
            'Instant shortcuts to navigate directly to restrooms and elevators with one tap.',
        borderRadius: 18.0,
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      ),
      AppTourStep(
        id: 'location_panel',
        key: locationPanelKey,
        titleAr: 'موقعك الحالي داخل المبنى',
        titleEn: 'Current Location',
        descriptionAr: 'يعرض مكانك الدقيق داخل المبنى تلقائياً.',
        descriptionEn:
            'Displays your exact location inside the building automatically.',
        borderRadius: 18.0,
        padding: const EdgeInsets.all(6.0),
      ),
      AppTourStep(
        id: 'floor_badge',
        key: floorBadgeKey,
        titleAr: 'رقم الدور الحالي',
        titleEn: 'Current Floor',
        descriptionAr: 'يوضح رقم الطابق المتواجد به حالياً داخل المبنى.',
        descriptionEn:
            'Shows the floor number you are currently on inside the building.',
        borderRadius: 16.0,
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      ),
      AppTourStep(
        id: 'start_button',
        key: startButtonKey,
        titleAr: 'بدء الملاحة',
        titleEn: 'Start Navigation',
        descriptionAr:
            'بعد اختيار وجهتك، اضغط هنا للانتقال إلى شاشة الملاحة والإرشادات بالأسهم خطوة بخطوة.',
        descriptionEn:
            'Once you choose a destination, tap here for step-by-step navigation instructions.',
        borderRadius: 28.0,
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      ),
      AppTourStep(
        id: 'app_bar_actions',
        key: appBarKey,
        titleAr: 'الإعدادات واللغة',
        titleEn: 'Settings & Language',
        descriptionAr:
            'بدّل بين اللغتين (عربي/إنجليزي)، أو خصص الوضع الليلي من القائمة.',
        descriptionEn:
            'Toggle between Arabic & English, or customize dark mode from the menu.',
        borderRadius: 14.0,
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
      ),
    ];

    // 2) خطوات شاشة الملاحة الحية (Active Navigation)
    activeSteps = [
      AppTourStep(
        id: 'destination_header',
        key: destinationHeaderKey,
        titleAr: 'عنوان الوجهة والدور المطلوب',
        titleEn: 'Destination & Floor Header',
        descriptionAr:
            'يعرض اسم الوجهة التي تتجه إليها ورقم الطابق المتواجدة به داخل المبنى.',
        descriptionEn:
            'Displays your active destination name and the target floor number.',
        borderRadius: 16.0,
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      ),
      AppTourStep(
        id: 'direction_hero',
        key: directionHeroKey,
        titleAr: 'السهم التوجيهي الذكي',
        titleEn: 'Smart Direction Arrow',
        descriptionAr: 'سهم تفاعلي يوجهك لحظياً نحو اتجاه خطوتك التالية في المسار.',
        descriptionEn:
            'Interactive arrow indicating your next direction in real-time along the route.',
        borderRadius: 24.0,
        padding: const EdgeInsets.all(8.0),
      ),
      AppTourStep(
        id: 'route_progress',
        key: routeProgressKey,
        titleAr: 'متابعة تقدم المسار',
        titleEn: 'Route Progress Tracker',
        descriptionAr:
            'يوضح خطواتك المتبقية، والمسافة، وتأكيد سيرك على المسار الصحيح خطوة بخطوة.',
        descriptionEn:
            'Tracks remaining steps, distance, and confirms if you are on the right path.',
        borderRadius: 18.0,
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
      ),
      AppTourStep(
        id: 'cancel_button',
        key: cancelButtonKey,
        titleAr: 'إنهاء أو إلغاء الملاحة',
        titleEn: 'End or Cancel Navigation',
        descriptionAr:
            'يمكنك إيقاف إرشادات الملاحة في أي وقت والعودة للشاشة الرئيسية بنقرة واحدة.',
        descriptionEn:
            'Stop guidance anytime and return to the home screen with a single tap.',
        borderRadius: 28.0,
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      ),
    ];
  }

  /// فحص وحساب مستطيل العنصر المستهدف مع تحويل دقيق للإحداثيات المحلية
  ///
  /// تحويل إحداثيات العنصر نسبة إلى [ancestor] (Overlay RenderBox)
  /// يحل تماماً مشكلة الإزاحة الناتجة عن شريط الحالة (Status Bar) أو الـ SafeArea.
  Rect? getTargetRect(
    GlobalKey key, {
    EdgeInsets? padding,
    RenderBox? ancestor,
  }) {
    final context = key.currentContext;
    if (context == null) return null;

    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize || renderBox.size.isEmpty) {
      return null;
    }

    final pad = padding ?? const EdgeInsets.all(8.0);
    final size = renderBox.size;
    final Offset localOffset;

    if (ancestor != null && ancestor.hasSize) {
      localOffset = ancestor.globalToLocal(renderBox.localToGlobal(Offset.zero));
    } else {
      localOffset = renderBox.localToGlobal(Offset.zero);
    }

    return Rect.fromLTWH(
      localOffset.dx - pad.left,
      localOffset.dy - pad.top,
      size.width + pad.horizontal,
      size.height + pad.vertical,
    );
  }

  /// التحقق وبدء جولة الشاشة الرئيسية تلقائياً عند أول فتح
  Future<void> checkAndStartIdleTour() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(idleTourVersionKey) ?? false;
    if (!hasSeen) {
      AppLogger.info('[AppTour] First launch -> Starting Idle Tour');
      startTour(mode: TourMode.idle, force: false);
    }
  }

  /// التحقق وبدء جولة الملاحة النشطة تلقائياً عند أول بدء ملاحة
  Future<void> checkAndStartActiveTour() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(activeTourVersionKey) ?? false;
    if (!hasSeen) {
      AppLogger.info('[AppTour] First active navigation -> Starting Active Tour');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 350), () {
          startTour(mode: TourMode.active, force: false);
        });
      });
    }
  }

  /// بدء الجولة التعريفية حسب النمط المحدد
  Future<void> startTour({
    TourMode mode = TourMode.idle,
    bool force = false,
  }) async {
    currentTourMode.value = mode;
    final stepsList = currentSteps;

    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final key =
          mode == TourMode.idle ? idleTourVersionKey : activeTourVersionKey;
      if (prefs.getBool(key) == true) return;
    }

    // البحث عن أول خطوة عنصرها المستهدف جاهز ومرسوم
    int initialStep = -1;
    for (int i = 0; i < stepsList.length; i++) {
      if (getTargetRect(stepsList[i].key, padding: stepsList[i].padding) != null) {
        initialStep = i;
        break;
      }
    }

    if (initialStep == -1) {
      AppLogger.warn(
        '[AppTour] No valid targets found on screen for mode: ${mode.name}',
      );
      return;
    }

    currentStep.value = initialStep;
    isTourActive.value = true;
    AppLogger.info(
      '[AppTour] Started (${mode.name}) at step $initialStep (${stepsList[initialStep].id})',
    );
  }

  /// الانتقال للخطوة التالية مع قاعدة Fallback أوتوماتيكية
  void nextStep({RenderBox? ancestor}) {
    final stepsList = currentSteps;
    int next = currentStep.value + 1;
    while (next < stepsList.length) {
      if (getTargetRect(
            stepsList[next].key,
            padding: stepsList[next].padding,
            ancestor: ancestor,
          ) !=
          null) {
        currentStep.value = next;
        AppLogger.debug(
          '[AppTour] Advanced to step $next (${stepsList[next].id})',
        );
        return;
      }
      AppLogger.warn(
        '[AppTour] Step $next (${stepsList[next].id}) target missing -> auto-skipping',
      );
      next++;
    }

    completeTour();
  }

  /// الرجوع للخطوة السابقة مع فحص الصلاحية
  void previousStep({RenderBox? ancestor}) {
    final stepsList = currentSteps;
    int prev = currentStep.value - 1;
    while (prev >= 0) {
      if (getTargetRect(
            stepsList[prev].key,
            padding: stepsList[prev].padding,
            ancestor: ancestor,
          ) !=
          null) {
        currentStep.value = prev;
        AppLogger.debug(
          '[AppTour] Returned to step $prev (${stepsList[prev].id})',
        );
        return;
      }
      prev--;
    }
  }

  /// تخطي الجولة وحفظ اكتمالها
  Future<void> skipTour() async {
    isTourActive.value = false;
    final prefs = await SharedPreferences.getInstance();
    final key = currentTourMode.value == TourMode.idle
        ? idleTourVersionKey
        : activeTourVersionKey;
    await prefs.setBool(key, true);
    AppLogger.info('[AppTour] Tour (${currentTourMode.value.name}) skipped.');
  }

  /// إتمام الجولة وحفظ اكتمالها
  Future<void> completeTour() async {
    isTourActive.value = false;
    final prefs = await SharedPreferences.getInstance();
    final key = currentTourMode.value == TourMode.idle
        ? idleTourVersionKey
        : activeTourVersionKey;
    await prefs.setBool(key, true);
    AppLogger.info('[AppTour] Tour (${currentTourMode.value.name}) completed.');
  }

  /// طلب إعادة تشغيل الجولة من شاشات أخرى
  void requestTourReplay({TourMode mode = TourMode.idle}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        startTour(mode: mode, force: true);
      });
    });
  }

  AppTourStep? get currentStepData {
    final stepsList = currentSteps;
    if (currentStep.value >= 0 && currentStep.value < stepsList.length) {
      return stepsList[currentStep.value];
    }
    return null;
  }
}
