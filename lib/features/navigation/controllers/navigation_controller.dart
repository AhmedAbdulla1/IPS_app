import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/navigation_destination.dart';
import '../utils/arabic_search_utils.dart';
import '../../../controllers/beacon_controller.dart';
import '../../../controllers/compass_controller.dart';
import '../../../controllers/navigation_controller.dart' as legacy;
import '../../../utils/constants.dart' show LevelNavigation;

/// Controller خاص بشاشة التنقل الرئيسية.
///
/// ملاحظة تسمية: الاسم مش "NavigationController" رغم إن ده أقرب اسم منطقي،
/// عشان GetX بيخزّن الـ controllers بالاسم البسيط للكلاس (String) مش
/// بالمسار الكامل بتاعه — فلو سميناه نفس اسم NavigationController اللي في
/// lib/controllers/navigation_controller.dart (اللي فيه A* الحقيقي)،
/// GetX هيتلخبط بينهم وقت Get.put/Get.find حتى لو الكومبايلر شايفهم نوعين
/// مختلفين تمامًا. NavigationScreenController بيتجنب التصادم من الأساس.
///
/// دي طبقة "عرض" بتوصل UI الشاشة (idle/active) بمنطق التنقل الحقيقي:
/// - [BeaconController]        → تحديد الموقع الحالي فعليًا عن طريق BLE
/// - [legacy.NavigationController] → حساب المسار (A*) وتتبّع الاتجاه/الدور
/// - [CompassController]       → اتجاه البوصلة الفعلي لحساب زاوية السهم
///
/// الحالتين الأساسيتين للشاشة:
/// 1) isNavigating == false → الحالة الابتدائية: بتعرض موقع المستخدم الحالي
///    (بيانات حقيقية من BeaconController، مش placeholder).
/// 2) isNavigating == true → بعد ما المستخدم يختار وجهة ويبدأ التوجيه،
///    الشاشة تتحول لعرض سهم الاتجاه المحسوب فعليًا من فرق (اتجاه المسار -
///    اتجاه البوصلة)، ومقتفية levelNavigation من الـ pathfinding الحقيقي.
///
/// اختيار الوجهة بيحصل بـ 3 طرق:
/// - من شريط البحث (كتابة + اختيار من النتائج المفلترة) → يحتاج ضغط زرار "بدء"
/// - من المنيو (فتح القائمة الكاملة من غير كتابة) → يحتاج ضغط زرار "بدء"
/// - من أزرار الاختصار السريعة (دورات مياه/مصاعد/مخارج/كافيتيريا) → بدء فوري
///   (لسه معطّلة فعليًا لحد ما تتضاف نقاط حقيقية ليها — راجع navigation_destination.dart)
class NavigationScreenController extends GetxController {
  final beaconController = Get.find<BeaconController>();
  final compassController = Get.find<CompassController>();
  final legacyNav = Get.find<legacy.NavigationController>();

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
  final RxString currentLocationLabel = 'جارِ تحديد موقعك...'.obs;

  // ------- الدور الحالي — متزامن فعليًا مع BeaconController -------
  final RxInt currentFloor = 0.obs;

  // ------- بيانات الاتجاه — محسوبة فعليًا من legacyNav + البوصلة -------
  final RxString currentDirection = 'straight'.obs;
  final RxString directionInstruction = 'جارِ تحديد المسار...'.obs;
  final RxString directionSubInstruction = ''.obs;

  // ------- تقدّم المسار — محسوب فعليًا من legacyNav.pathArray -------
  final RxInt totalRouteSteps = 0.obs;
  final RxInt currentRouteStep = 0.obs;
  final RxString remainingDistanceLabel = ''.obs;
  final RxInt targetFloor = 0.obs;
  // ملاحظة: مفيش منطق فعلي لاكتشاف "خروج عن المسار" في الكود القديم لسه،
  // فالقيمة دي ثابتة true دلوقتي. TODO: اربطها بمنطق كشف انحراف حقيقي
  // لما يتضاف (مقارنة موقع البيكون الحالي بالنود المتوقع في pathArray).
  final RxBool isOnCorrectPath = true.obs;

  // طول المسار الأصلي وقت بدء التوجيه (لحساب currentRouteStep لاحقًا،
  // لأن legacyNav.pathArray بيتقلص أول ما المستخدم يتحرك).
  int _initialPathLength = 0;

  // ------- الوجهات (اختصارات ثابتة + نقاط حقيقية من خريطة المبنى) -------
  final RxList<BuildingDestination> _allDestinations =
      <BuildingDestination>[].obs;
  List<BuildingDestination> get allDestinations => _allDestinations;
  List<BuildingDestination> get quickShortcuts =>
      NavigationDestinationsData.quickShortcuts;

  @override
  void onInit() {
    super.onInit();
    _buildDestinationList();
    searchResults.assignAll(allDestinations);
    searchFocusNode.addListener(() {
      if (searchFocusNode.hasFocus) {
        openDropdown();
      }
    });

    // تزامن مستمر مع الموقع الحقيقي (بيتحدث كل ما بيكون قريب أقوى يتغير)
    _syncIdleState();
    ever(beaconController.currentLocation, (_) => _syncIdleState());
    ever(beaconController.haveCurrentLocation, (_) => _syncIdleState());

    // تزامن مستمر مع حالة التوجيه الفعلية (pathfinding + بوصلة)
    _refreshActiveNavState();
    ever(legacyNav.levelNavigation, (_) => _refreshActiveNavState());
    ever(legacyNav.directionDegree, (_) => _refreshActiveNavState());
    ever(legacyNav.pathArrayLength, (_) => _refreshActiveNavState());
    ever(legacyNav.reachedDestination, (_) => _refreshActiveNavState());
    ever(compassController.heading, (_) => _refreshActiveNavState());
  }

  @override
  void onClose() {
    searchTextController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  /// بيبني قائمة الوجهات القابلة للبحث: الاختصارات السريعة + كل نقطة حقيقية
  /// موجودة في BeaconController.locationList (خريطة المبنى الفعلية).
  void _buildDestinationList() {
    final realDestinations = beaconController.locationList
        .map(
          (loc) => BuildingDestination(
            id: 'poi_${loc.nodeID}',
            name: loc.name,
            category: DestinationCategory.office,
            icon: Icons.meeting_room_rounded,
            nodeID: loc.nodeID,
          ),
        )
        .toList();

    _allDestinations.assignAll([
      ...NavigationDestinationsData.quickShortcuts,
      ...realDestinations,
    ]);
  }

  /// بيحدّث بيانات "الموقع الحالي" في الشاشة الابتدائية من BeaconController
  /// الحقيقي (مش placeholder).
  void _syncIdleState() {
    isLocationDetermined.value = beaconController.haveCurrentLocation.value;
    final loc = beaconController.currentLocation.value;
    currentLocationLabel.value =
        beaconController.haveCurrentLocation.value && loc.name.isNotEmpty
            ? loc.name.tr
            : 'جارِ تحديد موقعك...'.tr;
    currentFloor.value = loc.level;
  }

  double _relativeAngle() {
    double direction =
        legacyNav.directionDegree.value - compassController.heading.value;
    direction = direction % 360;
    if (direction < 0) direction += 360;
    return direction;
  }

  /// بيحدّث سهم الاتجاه/التعليمات/شريط التقدّم من حالة legacyNav الحقيقية
  /// (levelNavigation + directionDegree + pathArrayLength) وزاوية البوصلة.
  void _refreshActiveNavState() {
    final floor = beaconController.currentLocation.value.level;

    switch (legacyNav.levelNavigation.value) {
      case LevelNavigation.go_up:
        currentDirection.value = 'straight';
        directionInstruction.value = 'اصعد للدور التالي';
        directionSubInstruction.value = 'خُد المصعد أو السلم لأعلى';
        targetFloor.value = floor + 1;
        break;
      case LevelNavigation.go_down:
        currentDirection.value = 'straight';
        directionInstruction.value = 'انزل للدور التالي';
        directionSubInstruction.value = 'خُد المصعد أو السلم لأسفل';
        targetFloor.value = floor - 1;
        break;
      case LevelNavigation.reach_destination:
        currentDirection.value = 'straight';
        directionInstruction.value = 'لقد وصلت إلى وجهتك';
        directionSubInstruction.value = 'يمكنك إلغاء الملاحة الآن';
        targetFloor.value = floor;
        break;
      case LevelNavigation.empty:
        currentDirection.value = 'straight';
        directionInstruction.value = 'جارِ تحديد المسار...';
        directionSubInstruction.value = 'حافظ على تفعيل البلوتوث والموقع';
        targetFloor.value = floor;
        break;
      case LevelNavigation.same_level:
      final angle = _relativeAngle();
        if (angle > 315 || angle <= 45) {
          currentDirection.value = 'straight';
          directionInstruction.value = 'استمر مستقيم';
        } else if (angle > 45 && angle <= 135) {
          currentDirection.value = 'right';
          directionInstruction.value = 'انعطف يمين';
        } else if (angle > 135 && angle <= 225) {
          currentDirection.value = 'uturn';
          directionInstruction.value = 'استدر للخلف';
        } else {
          currentDirection.value = 'left';
          directionInstruction.value = 'انعطف يسار';
        }
        directionSubInstruction.value = 'استمر في هذا الاتجاه';
        targetFloor.value = floor;
    }

    // TODO: كشف انحراف حقيقي عن المسار لسه مش موجود في legacyNav.
    isOnCorrectPath.value = true;

    final remaining = int.tryParse(legacyNav.pathArrayLength.value) ?? 0;
    final total = _initialPathLength == 0 ? remaining : _initialPathLength;
    totalRouteSteps.value = total;
    currentRouteStep.value = (total - remaining).clamp(0, total);
    remainingDistanceLabel.value =
        remaining <= 0 ? 'وصلت' : '$remaining خطوة متبقية';
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
    // ملاحظة: كانت هنا `destination.name` من غير `.tr`، فحتى لو الترجمة
    // موجودة في AppTranslations، ماكانتش بتتطبق على شريط البحث بعد
    // الاختيار (بعكس عرض القائمة نفسها اللي كان بيستخدم `item.name.tr` صح).
    searchTextController.text = destination.name.tr;
    closeDropdown();

    if (immediate) {
      _tryStartNavigation(destination);
    }
  }

  void onShortcutTap(BuildingDestination facility) {
    selectDestination(facility, immediate: true);
  }

  /// اختيار نوع دورات المياه بعد بوب "رجالي/حريمي" (شايفه فيو في IdleHomeScreen).
  void selectRestroomVariant({required bool isMale}) {
    final variant = isMale
        ? NavigationDestinationsData.restroomsMale
        : NavigationDestinationsData.restroomsFemale;
    selectDestination(variant, immediate: true);
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

  void _tryStartNavigation(BuildingDestination destination) {
    if (destination.nodeID == null) {
      Get.snackbar(
        'غير متاح حاليًا'.tr,
        'وجهة "@name" لسه مفيش لها نقطة في خريطة المبنى.'
            .trParams({'name': destination.name.tr}),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!beaconController.haveCurrentLocation.value) {
      Get.snackbar(
        'لسه بنحدد موقعك'.tr,
        'استنى لحظة لحد ما نلاقي أقرب نقطة ليك وحاول تاني.'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    beaconController.setDestination(destination.nodeID!);
    legacyNav.startNavigation(
      beaconController.poiNodes,
      beaconController.poiList,
      beaconController.currentLocation.value.nodeID,
      destination.nodeID!,
    );
    _initialPathLength = legacyNav.pathArray.length;
    _refreshActiveNavState();
    isNavigating.value = true;
  }

  /// رجوع لحالة "الموقع الحالي" الابتدائية (مثلاً لو المستخدم لغى التوجيه)
  void endNavigation() {
    legacyNav.cancelNavigation();
    _initialPathLength = 0;
    isNavigating.value = false;
    clearSelection();
  }

  void updateFloor(int floor) {
    currentFloor.value = floor;
  }
}
