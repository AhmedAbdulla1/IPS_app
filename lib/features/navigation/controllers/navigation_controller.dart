import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/navigation_destination.dart';
import '../utils/arabic_search_utils.dart';
import '../../../controllers/beacon_controller.dart';
import '../../../controllers/compass_controller.dart';
import '../../../core/localization/locale_controller.dart';
import '../domain/entities/building_graph.dart';
import '../domain/entities/nav_edge.dart' as VerticalDirection show VerticalDirection  ;
import '../domain/entities/nav_node.dart';
import '../domain/entities/path_step.dart';
import '../domain/repositories/navigation_repository.dart';
import '../domain/usecases/find_path_usecase.dart';
import '../domain/usecases/path_not_found_exception.dart';

/// Controller خاص بشاشة التنقل الرئيسية.
///
/// ملاحظة تسمية: الاسم مش "NavigationController" رغم إن ده أقرب اسم منطقي،
/// عشان GetX بيخزّن الـ controllers بالاسم البسيط للكلاس (String) مش
/// بالمسار الكامل بتاعه — فلو سميناه نفس اسم NavigationController اللي في
/// lib/controllers/navigation_controller.dart (الـ A* القديم)، GetX هيتلخبط
/// بينهم وقت Get.put/Get.find حتى لو الكومبايلر شايفهم نوعين مختلفين تمامًا.
/// NavigationScreenController بيتجنب التصادم من الأساس.
///
/// ملاحظة معمارية مهمة: الكنترولر ده **مبيعتمدش على NavigationController
/// القديم خالص** — بيحسب المسار بنفسه عن طريق [FindPathUseCase] على
/// [BuildingGraph] الحقيقي الجاي من Supabase (نفس المحرك اللي اتصمم في
/// domain/usecases). القديم لسه موجود ومسجّل في main.dart لأن شاشات تانية
/// (calibration/onboarding القديمة) ممكن لسه تعتمد عليه، لكن مفيش أي محرك
/// A* اتنين بيشتغلوا مع بعض على نفس الشاشة دلوقتي.
///
/// دي طبقة "عرض" بتوصل UI الشاشة (idle/active) بمنطق التنقل الحقيقي:
/// - [BeaconController]     → تحديد الموقع الحالي فعليًا عن طريق BLE
/// - [FindPathUseCase]      → حساب المسار (A*) على الجراف كامل، شامل
///   الأدوار المتعددة والاتصال الرأسي كـ edge عادي
/// - [CompassController]    → اتجاه البوصلة الفعلي لحساب زاوية السهم
///
/// الحالتين الأساسيتين للشاشة:
/// 1) isNavigating == false → الحالة الابتدائية: بتعرض موقع المستخدم الحالي
///    (بيانات حقيقية من BeaconController).
/// 2) isNavigating == true → بعد ما المستخدم يختار وجهة ويبدأ التوجيه،
///    الشاشة تتحول لعرض سهم الاتجاه المحسوب من فرق (heading الخطوة الحالية
///    في المسار - اتجاه البوصلة)، مع إعادة حساب تلقائي للمسار (dynamic
///    replanning) لو المستخدم اتحرك لنقطة برة المسار المتوقع.
///
/// اختيار الوجهة بيحصل بـ 3 طرق:
/// - من شريط البحث (كتابة + اختيار من النتائج المفلترة) → يحتاج ضغط زرار "بدء"
/// - من المنيو (فتح القائمة الكاملة من غير كتابة) → يحتاج ضغط زرار "بدء"
/// - من أزرار الاختصار السريعة (دورات مياه/مصاعد/مخارج/كافيتيريا) → بدء فوري،
///   بيتحل مباشرة من نقاط المرافق الثابتة على العقد نفسها (node.facility_type)
///   — راجع توثيق _resolveNearestReachableDestination.
///
/// تحميل الجراف (loadGraph) بيمر دايمًا على [_safeLoadGraph] بدل ما يتنادى
/// مباشرة: [NavigationRepository] بيرجع تلقائيًا لكاش محلي دائم لو الشبكة
/// فشلت، لكن لو مفيش نت ومفيش كاش خالص (أول تشغيل من غير اتصال)
/// الاستثناء الأصلي بيوصل هنا، فبنمسكه ونعرض رسالة واضحة للمستخدم بدل ما
/// الشاشة تقفل فجأة (Unhandled Exception).
class NavigationScreenController extends GetxController {
  final beaconController = Get.find<BeaconController>();
  final compassController = Get.find<CompassController>();
  final _navigationRepository = Get.find<NavigationRepository>();
  final _findPath = Get.find<FindPathUseCase>();

  // ------- التحكم في شريط البحث -------
  final TextEditingController searchTextController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  // ------- حالة الدروب داون -------
  final RxBool isDropdownOpen = false.obs;
  final RxList<BuildingDestination> searchResults =
      <BuildingDestination>[].obs;

  // ------- الوجهة المختارة -------
  final Rx<BuildingDestination?> selectedDestination =
      Rx<BuildingDestination?>(null);

  // ------- حالة الشاشة: موقع حالي (ابتدائي) أو توجيه (بعد البدء) -------
  final RxBool isNavigating = false.obs;

  // ------- بيانات الموقع الحالي — متزامنة فعليًا مع BeaconController -------
  final RxBool isLocationDetermined = false.obs;
  final RxString currentLocationLabel = ''.obs;

  // ------- الدور الحالي — متزامن فعليًا مع BeaconController -------
  final RxInt currentFloor = 0.obs;

  // ------- بيانات الاتجاه — محسوبة من المسار الحقيقي + البوصلة -------
  final RxString currentDirection = 'straight'.obs;
  final RxString directionInstruction = ''.obs;
  final RxString directionSubInstruction = ''.obs;

  // ------- تقدّم المسار — محسوب من _currentPath الحقيقي -------
  final RxInt totalRouteSteps = 0.obs;
  final RxInt currentRouteStep = 0.obs;
  final RxString remainingDistanceLabel = ''.obs;
  final RxInt targetFloor = 0.obs;
  final RxBool isOnCorrectPath = true.obs;

  // ------- حالة الاتصال بخريطة المبنى (Supabase) -------
  // بتتحدّث كل ما نحاول نحمّل الجراف، عشان الشاشة تقدر تعرض بانر بسيط
  // "بيانات مخزّنة" وقت الأوفلاين من غير ما تحتاج snackbar متكرر.
  final RxBool isUsingCachedGraph = false.obs;
  bool _graphErrorNoticeShown = false;

  // ------- حالة المسار الحقيقي (ناتج FindPathUseCase) -------
  // القائمة الكاملة للخطوات من البداية للوجهة، و_currentStepIndex هو
  // "الخطوة اللي المستخدم المفروض يوصلها بعد كده" (0 = نقطة البداية نفسها).
  List<PathStep> _currentPath = [];
  int _currentStepIndex = 0;
  int _consecutiveOffPathReadings = 0;

  // ------- الوجهات (اختصارات ثابتة + نقاط حقيقية من خريطة المبنى) -------
  final RxList<BuildingDestination> _allDestinations =
      <BuildingDestination>[].obs;
  List<BuildingDestination> get allDestinations => _allDestinations;
  List<BuildingDestination> get quickShortcuts =>
      NavigationDestinationsData.quickShortcuts;

  bool get _isArabic => Get.find<LocaleController>().isArabic;

  @override
  void onInit() {
    super.onInit();
    // بداية ابتدائية بالاختصارات الثابتة بس، لحد ما الجراف الحقيقي يوصل
    // (البناء الكامل async — راجع _buildDestinationList).
    _allDestinations.assignAll(NavigationDestinationsData.quickShortcuts);
    searchResults.assignAll(allDestinations);
    _buildDestinationList();

    searchFocusNode.addListener(() {
      if (searchFocusNode.hasFocus) {
        openDropdown();
      }
    });

    // تزامن مستمر: كل ما موقع البيكون يتغيّر، حدّث الحالة الابتدائية، وكمان
    // لو التوجيه شغال، شيك هل وصلنا للخطوة الجاية في المسار ولا حصل انحراف.
    _syncIdleState();
    ever(beaconController.currentLocation, (_) {
      _syncIdleState();
      if (isNavigating.value) _advanceOrReplan();
    });
    ever(beaconController.haveCurrentLocation, (_) => _syncIdleState());

    // تزامن مستمر مع الإحداثيات المترية للوصول للأبواب الافتراضية
    ever(beaconController.currentCoordinates, (_) {
      if (isNavigating.value) _checkMetricArrivalOrProgress();
    });

    // لو المستخدم بدّل اللغة والتطبيق شغال، حدّث كل النصوص المعروضة فورًا
    // (localizedName بيتحسب وقت العرض، بس النصوص الوصفية زي "أنت الآن في"
    // محتاجة إعادة تقييم صريحة).
    ever(Get.find<LocaleController>().locale, (_) {
      _syncIdleState();
      if (isNavigating.value) _refreshActiveNavState();
    });

    // تزامن مستمر مع البوصلة وقت التوجيه بس (بيرجع فورًا لو مفيش مسار شغال).
    ever(compassController.heading, (_) {
      if (isNavigating.value) _refreshActiveNavState();
    });
  }

  @override
  void onClose() {
    searchTextController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  /// غلاف آمن حوالين [NavigationRepository.loadGraph]: بيمسك أي فشل شبكة
  /// (مفيش نت، تعذّر الوصول لسوبابيز... إلخ) بدل ما يسيبه يطلع كـ
  /// Unhandled Exception ويوقف الشاشة. بيرجّع null لو فشل التحميل نهائيًا
  /// (يعني مفيش نت *و* مفيش كاش محلي خالص)، وفي الحالة دي بيعرض رسالة
  /// واضحة للمستخدم توضح المشكلة. لو نجح لكن من كاش، بيعرض تنبيه بسيط
  /// إنه شايف بيانات مخزّنة.
  Future<BuildingGraph?> _safeLoadGraph({bool forceRefresh = false}) async {
    try {
      final graph =
          await _navigationRepository.loadGraph(forceRefresh: forceRefresh);
      isUsingCachedGraph.value = graph.isFromCache;
      if (graph.isFromCache) {
        _showOfflineCacheNotice();
      }
      return graph;
    } catch (e) {
      isUsingCachedGraph.value = false;
      _showGraphLoadError();
      return null;
    }
  }

  void _showGraphLoadError() {
    if (_graphErrorNoticeShown) return;
    _graphErrorNoticeShown = true;
    final isArabic = _isArabic;
    Get.snackbar(
      isArabic ? 'لا يوجد اتصال بالإنترنت' : 'No internet connection',
      isArabic
          ? 'تعذّر تحميل خريطة المبنى لأنه لا يوجد اتصال بالإنترنت ومفيش نسخة محفوظة على جهازك بعد. تحقق من اتصالك وحاول مرة أخرى.'
          : 'Couldn\'t load the building map — no internet connection and no saved copy on this device yet. Check your connection and try again.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
      icon: const Icon(Icons.wifi_off_rounded, color: Colors.white),
      backgroundColor: const Color(0xFFB3261E),
      colorText: Colors.white,
      isDismissible: true,
    );
  }

  void _showOfflineCacheNotice() {
    final isArabic = _isArabic;
    Get.snackbar(
      isArabic ? 'وضع عدم الاتصال' : 'Offline mode',
      isArabic
          ? 'لا يوجد اتصال بالإنترنت حاليًا — بتشوف آخر نسخة محفوظة من خريطة المبنى.'
          : 'No internet connection right now — showing the last saved copy of the building map.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.cloud_off_rounded, color: Colors.white),
    );
  }

  /// بيبني قائمة الوجهات القابلة للبحث مباشرة من [BuildingGraph.destinations] — مش
  /// من عقد الخريطة مباشرة، لأن الوجهة الواحدة ممكن تربط بأكتر من عقدة
  /// فيزيائية (زي مدخل كبير بيغطيه بيكونين)، والعكس: عقدة واحدة
  /// ممكن تمثّل أكتر من وجهة (زي حمام + مكتب في نفس النقطة). راجع
  /// توثيق Destination في domain/entities/destination.dart.
  ///
  /// ملاحظة: نقاط المرافق (حمام/أسانسير/مخرج/كافيتيريا) **مش** بتتضاف هنا،
  /// وده مقصود — دي أماكن معروفة وثابتة، مش وجهات يدور عليها حد بالاسم،
  /// فبتتحل مباشرة من node.facility_type وقت الضغط على الاختصار السريع
  /// (راجع _resolveNearestReachableDestination) من غير ما تحتاج تظهر في
  /// نتائج البحث أو المنيو.
  Future<void> _buildDestinationList() async {
    final graph = await _safeLoadGraph();
    if (graph == null) {
      // فشل التحميل نهائيًا (مفيش نت ومفيش كاش) — سيب القائمة بالاختصارات
      // الثابتة بس، الرسالة اتعرضت بالفعل من _safeLoadGraph.
      return;
    }

    final realDestinations = graph.destinations.map((destination) {
      final aliasTexts = [
        ...destination.aliasesAr,
        ...destination.aliasesEn,
      ];
      return BuildingDestination(
        id: 'dest_${destination.id}',
        nameAr: destination.nameAr,
        nameEn: destination.nameEn,
        category: DestinationCategory.office,
        icon: Icons.meeting_room_rounded,
        aliases: aliasTexts,
        nodeID: destination.primaryNodeId,
      );
    }).toList();

    _allDestinations.assignAll([
      ...NavigationDestinationsData.quickShortcuts,
      ...realDestinations,
    ]);

    // لو المستخدم لسه ما كتبش حاجة (أو الدروب داون مقفول)، حدّث نتائج
    // العرض بالقائمة الكاملة الجديدة.
    if (searchTextController.text.trim().isEmpty) {
      searchResults.assignAll(_allDestinations);
    } else {
      searchResults.assignAll(
        ArabicSearchUtils.search(_allDestinations, searchTextController.text),
      );
    }
  }

  /// بيحدّث بيانات "الموقع الحالي" في الشاشة الابتدائية من BeaconController
  /// الحقيقي، بالاسم المترجم حسب لغة الواجهة الحالية.
  void _syncIdleState() {
    isLocationDetermined.value = beaconController.haveCurrentLocation.value;
    final loc = beaconController.currentLocation.value;
    final isArabic = _isArabic;

    if (beaconController.haveCurrentLocation.value && loc.name.isNotEmpty) {
      final destinationsLabel = _destinationsLabelForNode(loc.nodeID, isArabic);
      if (destinationsLabel != null) {
        currentLocationLabel.value = destinationsLabel;
      } else {
        // Fallback: لسه مفيش وجهة مرتبطة بالعقدة دي في destinations (زي تقاطع/ممر
        // محدش ملهش وجهة بحث، أو الجراف لسه ما اتحملش)، فنرجع لاسم
        // العقدة الخام القديم.
        final hasEnglish = !isArabic && (loc.nameEn?.trim().isNotEmpty ?? false);
        currentLocationLabel.value = hasEnglish ? loc.nameEn! : loc.name;
      }
    } else {
      currentLocationLabel.value =
          isArabic ? 'جارِ تحديد موقعك...' : 'Locating your position...';
    }
    currentFloor.value = loc.level;
  }

  /// بيرجّع اسم/أسماء الأماكن الحقيقية (destinations) المرتبطة بالعقدة
  /// الفيزيائية دي — مش اسم العقدة الخام مباشرة. لو العقدة مرتبطة بأكتر
  /// من وجهة (زي حمام + مكتب في نفس النقطة)، بيرجّعهم كلهم مفصولين
  /// بفاصلة بدل ما يخترع واحد منهم تعسفيًا. بيرجّع null لو الجراف لسه ما
  /// اتحملش، أو مفيش أي وجهة مرتبطة بالعقدة دي أصلًا.
  String? _destinationsLabelForNode(int nodeId, bool isArabic) {
    final graph = _navigationRepository.cachedGraph;
    if (graph == null) return null;

    final matches =
        graph.destinations.where((d) => d.nodeIds.contains(nodeId)).toList();
    if (matches.isEmpty) return null;

    final names =
        matches.map((d) => isArabic ? d.nameAr : (d.nameEn ?? d.nameAr));
    return names.join(isArabic ? '، ' : ', ');
  }

  double _relativeAngle(double stepHeading) {
    double direction = stepHeading - compassController.heading.value;
    direction = direction % 360;
    if (direction < 0) direction += 360;
    return direction;
  }

  String _resolveDirectionWithDeadband(double angle, String prev) {
    const deadband = 10.0;

    if (prev == 'straight') {
      if (angle > (45 + deadband) && angle <= 135) return 'right';
      if (angle > 135 && angle <= 225) return 'uturn';
      if (angle > 225 && angle < (315 - deadband)) return 'left';
      return 'straight';
    } else if (prev == 'right') {
      if (angle <= (45 - deadband) || angle > 315) return 'straight';
      if (angle > (135 + deadband) && angle <= 225) return 'uturn';
      if (angle > 225 && angle <= 315) return 'left';
      return 'right';
    } else if (prev == 'uturn') {
      if (angle <= 45 || angle > 315) return 'straight';
      if (angle <= (135 - deadband) && angle > 45) return 'right';
      if (angle > (225 + deadband) && angle <= 315) return 'left';
      return 'uturn';
    } else if (prev == 'left') {
      if (angle >= (315 + deadband) || angle <= 45) return 'straight';
      if (angle > 45 && angle <= 135) return 'right';
      if (angle <= (225 - deadband) && angle > 135) return 'uturn';
      return 'left';
    }

    if (angle > 315 || angle <= 45) return 'straight';
    if (angle > 45 && angle <= 135) return 'right';
    if (angle > 135 && angle <= 225) return 'uturn';
    return 'left';
  }

  /// بيحدّث سهم الاتجاه/التعليمات/شريط التقدّم من _currentPath الحقيقي
  /// (ناتج FindPathUseCase) وزاوية البوصلة.
  void _refreshActiveNavState() {
    final isArabic = _isArabic;

    if (_currentPath.isEmpty || _currentStepIndex >= _currentPath.length) {
      currentDirection.value = 'arrived';
      directionInstruction.value =
          isArabic ? 'لقد وصلت إلى وجهتك' : 'You have reached your destination';
      directionSubInstruction.value =
          isArabic ? 'يمكنك إلغاء الملاحة الآن' : 'You can end navigation now';
      totalRouteSteps.value = _currentPath.isEmpty ? 0 : _currentPath.length - 1;
      currentRouteStep.value = totalRouteSteps.value;
      remainingDistanceLabel.value = isArabic ? 'وصلت' : 'Arrived';
      targetFloor.value = beaconController.currentLocation.value.level;
      isOnCorrectPath.value = true;
      return;
    }

    final step = _currentPath[_currentStepIndex];

    if (step.verticalDirection == VerticalDirection.VerticalDirection.up) {
      currentDirection.value = 'up';
      directionInstruction.value = isArabic ? 'اصعد للدور التالي' : 'Go up to the next floor';
      directionSubInstruction.value =
          isArabic ? 'خُد المصعد أو السلم لأعلى' : 'Take the elevator or stairs up';
    } else if (step.verticalDirection == VerticalDirection.VerticalDirection.down) {
      currentDirection.value = 'down';
      directionInstruction.value = isArabic ? 'انزل للدور التالي' : 'Go down to the next floor';
      directionSubInstruction.value =
          isArabic ? 'خُد المصعد أو السلم لأسفل' : 'Take the elevator or stairs down';
    } else {
      final angle = _relativeAngle(step.heading);
      final newDir = _resolveDirectionWithDeadband(angle, currentDirection.value);
      currentDirection.value = newDir;

      switch (newDir) {
        case 'straight':
          directionInstruction.value = isArabic ? 'استمر مستقيم' : 'Go straight';
          break;
        case 'right':
          directionInstruction.value = isArabic ? 'انعطف يمين' : 'Turn right';
          break;
        case 'uturn':
          directionInstruction.value = isArabic ? 'استدر للخلف' : 'Turn around';
          break;
        case 'left':
        default:
          directionInstruction.value = isArabic ? 'انعطف يسار' : 'Turn left';
          break;
      }
      directionSubInstruction.value =
          isArabic ? 'استمر في هذا الاتجاه' : 'Continue in this direction';
    }

    isOnCorrectPath.value = true; // إعادة الحساب التلقائي بتخلي المسار الحالي صح دايمًا

    totalRouteSteps.value = _currentPath.length - 1;
    currentRouteStep.value =
        (_currentStepIndex - 1).clamp(0, totalRouteSteps.value);

    double remainingMeters = _currentPath
        .sublist(_currentStepIndex)
        .fold<double>(0, (sum, s) => sum + s.legDistanceMeters);

    // إذا كان المستخدم في الخطوة الأخيرة، نحسب المسافة الحقيقية بدقة من الإحداثيات المستمرة
    if (_currentStepIndex == _currentPath.length - 1 && beaconController.currentCoordinates.value != null) {
      final userCoords = beaconController.currentCoordinates.value!;
      final destNode = _navigationRepository.cachedGraph?.nodeById(_currentPath.last.nodeId);
      if (destNode != null && destNode.x != null && destNode.y != null) {
        final dx = userCoords.x - destNode.x!;
        final dy = userCoords.y - destNode.y!;
        final realDist = math.sqrt(dx * dx + dy * dy);
        if (realDist < remainingMeters + 2.0) {
          remainingMeters = realDist;
        }
      }
    }

    remainingDistanceLabel.value = isArabic
        ? '${remainingMeters.round()} م متبقي'
        : '${remainingMeters.round()} m remaining';

    if (_currentStepIndex == _currentPath.length - 1 && remainingMeters <= 3.5) {
      directionSubInstruction.value = isArabic
          ? 'وجهتك قريبة جداً (تأكد من الباب على يمينك أو يسارك)'
          : 'Destination is right beside you';
    }

    final graph = _navigationRepository.cachedGraph;
    final node = graph?.nodeById(step.nodeId);
    final level = node != null ? graph?.levelsById[node.levelId]?.order : null;
    targetFloor.value = level ?? beaconController.currentLocation.value.level;
  }

  /// فحص الوصول المتري للوجهة (أبواب المكاتب بدون بيكون) عبر الإحداثيات المستمرة
  void _checkMetricArrivalOrProgress() {
    if (!isNavigating.value || _currentPath.isEmpty) return;
    if (_currentStepIndex >= _currentPath.length) return;

    final userCoords = beaconController.currentCoordinates.value;
    if (userCoords == null) return;

    final graph = _navigationRepository.cachedGraph;
    if (graph == null) return;

    final currentFloor = beaconController.currentLocation.value.level;

    // 1. فحص الوصول إلى الهدف النهائي (سواء كان له بيكون أو نود افتراضي لباب مكتب)
    final destNodeId = _currentPath.last.nodeId;
    final destNode = graph.nodeById(destNodeId);
    if (destNode != null && destNode.x != null && destNode.y != null) {
      final destFloor = graph.levelsById[destNode.levelId]?.order ?? 0;
      if (destFloor == currentFloor) {
        final dx = userCoords.x - destNode.x!;
        final dy = userCoords.y - destNode.y!;
        final dist = math.sqrt(dx * dx + dy * dy);

        // إذا اقترب المستخدم لمسافة 1.8 متر أو أقل من الباب
        if (dist <= 1.8) {
          print('[Navigation] 🎯 تم الوصول إلى باب الوجهة بالمسافة المترية (${dist.toStringAsFixed(2)}m)');
          _currentStepIndex = _currentPath.length; // يؤدي إلى تفعيل شاشة الوصول
          _refreshActiveNavState();
          return;
        }
      }
    }

    // 2. فحص النود الحالي في المسار لو كان نود افتراضي (بدون بيكون)
    final currentStep = _currentPath[_currentStepIndex];
    final stepNode = graph.nodeById(currentStep.nodeId);
    if (stepNode != null && stepNode.esp32Uuid == null && stepNode.x != null && stepNode.y != null) {
      final stepFloor = graph.levelsById[stepNode.levelId]?.order ?? 0;
      if (stepFloor == currentFloor) {
        final dx = userCoords.x - stepNode.x!;
        final dy = userCoords.y - stepNode.y!;
        final dist = math.sqrt(dx * dx + dy * dy);

        if (dist <= 1.8) {
          print('[Navigation] 🚶 تجاوز نود افتراضي على المسار (${dist.toStringAsFixed(2)}m)');
          _currentStepIndex = (_currentStepIndex + 1).clamp(0, _currentPath.length);
          _refreshActiveNavState();
          return;
        }
      }
    }
  }

  /// بيتنفذ كل ما موقع البيكون يتغيّر أثناء التوجيه:
  /// 1. يفحص المسار المتبقي للأمام بالكامل (لتخطي العقد المعطلة أو الاختصارات)
  /// 2. يفحص العقد السابقة القريبة لتجنب الهلع من إشارات عابرة
  /// 3. في حالة الانحراف الحقيقي، يشترط تكرار القراءة (Debounce) لـ 3 مرات
  ///    قبل إعادة حساب المسار ديناميكياً (dynamic replanning).
  Future<void> _advanceOrReplan() async {
    if (_currentPath.isEmpty) return;
    final currentNodeId = beaconController.currentLocation.value.nodeID;

    // ✅ الحالة 1: هل النود الحالية موجودة في أي خطوة لاحقة على المسار المتبقي؟
    // يغطي:
    // - الوصول للخطوة المتوقعة الحالية
    // - تخطي خطوة أو أكثر (إذا كانت نود معطلة أو أخذ النائب اختصاراً ووصل لنود تالية على نفس المسار)
    final futureIndex = _currentPath.indexWhere(
      (step) => step.nodeId == currentNodeId,
      _currentStepIndex,
    );

    if (futureIndex != -1) {
      _consecutiveOffPathReadings = 0;
      _currentStepIndex = (futureIndex + 1).clamp(0, _currentPath.length);
      _refreshActiveNavState();
      return;
    }

    // ✅ الحالة 2: هل النود الحالية هي إحدى النقاط السابقة القريبة (آخر خطوتين مثلاً)؟
    // قد يحدث بسبب تذبذب بسيط في التقاط إشارة بيكون النود السابقة
    final pastStartIndex = (_currentStepIndex - 2).clamp(0, _currentPath.length);
    final isRecentPast = _currentPath
        .sublist(pastStartIndex, _currentStepIndex)
        .any((step) => step.nodeId == currentNodeId);

    if (isRecentPast) {
      _consecutiveOffPathReadings = 0;
      _refreshActiveNavState();
      return;
    }

    // ⚠️ الحالة 3: قراءة لنود خارج المسار بالكامل:
    // نستخدم عداد تثبت (Debounce) لضمان عدم إعادة الحساب بسبب تشويش لحظي
    _consecutiveOffPathReadings++;
    if (_consecutiveOffPathReadings < 3) {
      print('[Navigation] ⏳ قراءة خارج المسار (نود $currentNodeId). جاري التأكد ($_consecutiveOffPathReadings/3)...');
      return;
    }

    // تأكد الانحراف بعد 3 قراءات متتالية: إعادة حساب المسار من النقطة الحالية
    _consecutiveOffPathReadings = 0;
    final destinationNodeId = _currentPath.last.nodeId;
    final graph =
        _navigationRepository.cachedGraph ?? await _safeLoadGraph();
    if (graph == null) {
      _refreshActiveNavState();
      return;
    }

    try {
      _currentPath = _findPath(graph, currentNodeId, destinationNodeId);
      _currentStepIndex = _currentPath.length > 1 ? 1 : 0;
      print('[Navigation] 🔄 Dynamic replan: تم إعادة التوجيه بنجاح من node $currentNodeId');
    } on PathNotFoundException {
      print('[Navigation] ⚠️ No path from current position ($currentNodeId)');
    }

    _refreshActiveNavState();
  }

  // ------- تفاعلات شريط البحث / المنيو -------

  void openDropdown() {
    if (searchTextController.text.trim().isEmpty) {
      searchResults.assignAll(allDestinations);
    }
    isDropdownOpen.value = true;
  }

  void closeDropdown() {
    isDropdownOpen.value = false;
    searchFocusNode.unfocus();
  }

  void onSearchChanged(String value) {
    if (value.trim().isEmpty) {
      searchResults.assignAll(allDestinations);
    } else {
      searchResults.assignAll(
        ArabicSearchUtils.search(allDestinations, value),
      );
    }
    isDropdownOpen.value = true;
  }

  /// اختيار وجهة — من البحث أو من المنيو (بيحتاج زرار بدء بعدها)،
  /// أو من اختصار سريع (immediate = true → بدء فوري من غير زرار).
  void selectDestination(BuildingDestination destination,
      {bool immediate = false}) {
    selectedDestination.value = destination;
    searchTextController.text = destination.localizedName(_isArabic);
    closeDropdown();

    if (immediate) {
      _tryStartNavigation(destination);
    }
  }

  void onShortcutTap(BuildingDestination facility) {
    if (facility.shortcutType == null) {
      selectDestination(facility, immediate: true);
      return;
    }
    final resolved = _resolveNearestReachableDestination(facility.shortcutType!);
    if (resolved == null) {
      _showUnavailableMessage(facility);
      return;
    }
    selectDestination(resolved, immediate: true);
  }

  /// اختيار نوع دورات المياه بعد بوب "رجالي/حريمي" (شايفه فيو في IdleHomeScreen).
  void selectRestroomVariant({required bool isMale}) {
    final placeholder = isMale
        ? NavigationDestinationsData.restroomsMale
        : NavigationDestinationsData.restroomsFemale;
    final resolved = _resolveNearestReachableDestination(placeholder.shortcutType!);
    if (resolved == null) {
      _showUnavailableMessage(placeholder);
      return;
    }
    selectDestination(resolved, immediate: true);
  }

  /// بيدور على كل عقد المرافق (nodes) المعلّمة بـ facility_type = [facilityType]
  /// مباشرة (نظام ثابت على مستوى نقطة الخريطة نفسها — راجع توثيق
  /// [NavNode.facilityType])، وبيحسب طول المسار الفعلي لكل واحدة من موقع
  /// المستخدم الحالي (عن طريق A*)، وبيرجّع أقرب واحدة قابلة للوصول فعليًا.
  ///
  /// ملاحظة معمارية مهمة: ده **مش** بحث في [BuildingGraph.destinations]
  /// (جدول الوجهات القابلة للبحث) — المرافق العامة زي دورات المياه
  /// والأسانسيرات والمخارج معروفة ومتوقعة في أي مبنى، فمفيش داعي تتسجل
  /// كـ "وجهة" يدور عليها المستخدم بالاسم. الأدمن بس بيحط facility_type
  /// على العقدة المناسبة في جدول nodes مباشرة (زي عمود عادي، من غير أي
  /// صف إضافي في destinations/destination_nodes)، والاختصار السريع بيقرأ
  /// منه مباشرة.
  ///
  /// بيرجّع null لو مفيش عقدة معلّمة بالنوع ده، أو موقع المستخدم لسه
  /// متحدد، أو مفيش واحدة منهم قابلة للوصول فعليًا من الموقع الحالي.
  BuildingDestination? _resolveNearestReachableDestination(String facilityType) {
    final graph = _navigationRepository.cachedGraph;
    if (graph == null) return null;
    if (!beaconController.haveCurrentLocation.value) return null;

    final startNodeId = beaconController.currentLocation.value.nodeID;
    final candidates = graph.nodesByFacilityType(facilityType);

    NavNode? best;
    double bestDistance = double.infinity;
    for (final candidate in candidates) {
      try {
        final path = _findPath(graph, startNodeId, candidate.id);
        final distance =
            path.fold<double>(0, (sum, s) => sum + s.legDistanceMeters);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = candidate;
        }
      } on PathNotFoundException {
        continue;
      }
    }

    if (best == null) return null;
    return BuildingDestination(
      id: 'facility_${best.id}',
      nameAr: best.nameAr,
      nameEn: best.nameEn,
      category: DestinationCategory.facility,
      icon: Icons.place_rounded,
      nodeID: best.id,
    );
  }

  void _showUnavailableMessage(BuildingDestination facility) {
    final isArabic = _isArabic;
    Get.snackbar(
      isArabic ? 'غير متاح حاليًا' : 'Not available yet',
      isArabic
          ? 'لسه مفيش نقطة "${facility.localizedName(isArabic)}" متاحة أو ممكن توصلها من موقعك الحالي.'
          : 'No reachable "${facility.localizedName(isArabic)}" point yet from your location.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void clearSelection() {
    selectedDestination.value = null;
    searchTextController.clear();
    searchResults.assignAll(allDestinations);
  }

  // ------- بدء/إنهاء التوجيه -------

  bool get canStart =>
      selectedDestination.value?.nodeID != null &&
      beaconController.haveCurrentLocation.value;

  void onStartPressed() {
    final destination = selectedDestination.value;
    if (destination == null) return;
    _tryStartNavigation(destination);
  }

  Future<void> _tryStartNavigation(BuildingDestination destination) async {
    final isArabic = _isArabic;
    print("[Destination] ${destination.nodeID} ");
    if (destination.nodeID == null) {
      Get.snackbar(
        isArabic ? 'غير متاح حاليًا' : 'Not available yet',
        isArabic
            ? 'وجهة "${destination.localizedName(isArabic)}" لسه مفيش لها نقطة في خريطة المبنى.'
            : '"${destination.localizedName(isArabic)}" doesn\'t have a mapped point yet.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!beaconController.haveCurrentLocation.value) {
      Get.snackbar(
        isArabic ? 'لسه بنحدد موقعك' : 'Still locating you',
        isArabic
            ? 'استنى لحظة لحد ما نلاقي أقرب نقطة ليك وحاول تاني.'
            : 'Please wait a moment while we find your nearest point, then try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final graph =
        _navigationRepository.cachedGraph ?? await _safeLoadGraph();
    if (graph == null) {
      // مفيش نت ومفيش كاش — الرسالة اتعرضت بالفعل من _safeLoadGraph.
      return;
    }
    final startNodeId = beaconController.currentLocation.value.nodeID;

    try {
      print('[Graph] ${graph.nodesById}');
      print('[Start Node Id] $startNodeId');
      _currentPath = _findPath(graph, startNodeId, destination.nodeID!);
    } on PathNotFoundException {
      Get.snackbar(
        isArabic ? 'تعذّر إيجاد مسار' : 'No route found',
        isArabic
            ? 'مفيش مسار متاح حاليًا لهذه الوجهة من موقعك.'
            : 'No available route to this destination from your location.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    print('[path] ccurrentpath: $_currentPath');

    _currentStepIndex = _currentPath.length > 1 ? 1 : 0;
    _consecutiveOffPathReadings = 0;
    beaconController.setDestination(destination.nodeID!);
    _refreshActiveNavState();
    isNavigating.value = true;
  }

  /// رجوع لحالة "الموقع الحالي" الابتدائية (مثلاً لو المستخدم لغى التوجيه)
  void endNavigation() {
    _currentPath = [];
    _currentStepIndex = 0;
    _consecutiveOffPathReadings = 0;
    isNavigating.value = false;
    clearSelection();
  }

  void updateFloor(int floor) {
    currentFloor.value = floor;
  }
}
