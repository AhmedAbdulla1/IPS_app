import 'package:flutter/material.dart';

/// تصنيف الوجهة داخل المبنى
enum DestinationCategory { hall, office, service, facility }

extension DestinationCategoryLabel on DestinationCategory {
  String get arabicLabel {
    switch (this) {
      case DestinationCategory.hall:
        return 'القاعات';
      case DestinationCategory.office:
        return 'المكاتب';
      case DestinationCategory.service:
        return 'الخدمات';
      case DestinationCategory.facility:
        return 'المرافق';
    }
  }
}

/// وجهة داخل خريطة المبنى (قاعة / مكتب / خدمة / مرفق سريع)
///
/// ملاحظة تسمية: الاسم مش "NavigationDestination" عشان فليتر نفسه عنده
/// كلاس بنفس الاسم بالظبط جوه material.dart (بتاع NavigationBar)، وأي
/// ملف بيعمل import لـ material.dart + الموديل ده مع بعض كان بيدّي
/// "ambiguous_import". BuildingDestination بيتجنب التصادم من الأساس.
class BuildingDestination {
  final String id;
  final String name;
  final DestinationCategory category;
  final IconData icon;

  /// كلمات بديلة/مرادفات بتساعد البحث الذكي يلاقي النتيجة
  final List<String> aliases;

  /// لو true، المكان ده بيظهر كزرار اختصار سريع تحت شريط البحث.
  final bool isQuickShortcut;

  /// نود التوجيه الحقيقي (POINode.nodeID في BeaconController.poiList) اللي
  /// الوجهة دي بتتحل ليه فعليًا لحساب المسار (A*). لو null، معناها لسه مفيش
  /// نود حقيقي مرتبط بالوجهة دي في خريطة المبنى (زي دورات المياه/المصاعد/
  /// المخارج/الكافيتيريا لحد ما تتضاف كنقاط فعلية) — NavigationController
  /// بيتشيك على القيمة دي قبل ما يحاول يبدأ توجيه ليها.
  final int? nodeID;

  const BuildingDestination({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    this.aliases = const [],
    this.isQuickShortcut = false,
    this.nodeID,
  });
}

/// الاختصارات السريعة الثابتة (أيقونات تحت شريط البحث).
/// دي مرافق عامة لسه مفيش لها نقاط (nodeID) في خريطة المبنى الحقيقية —
/// بمجرد ما تتضاف نقاط دورات مياه/مصاعد/مخارج/كافيتيريا فعلية في
/// BeaconController.fetchPoiNodes()، حط nodeID هنا وهيشتغلوا فورًا.
class NavigationDestinationsData {
  NavigationDestinationsData._();

  static const List<BuildingDestination> quickShortcuts = [
    BuildingDestination(
      id: 'restrooms',
      name: 'دورات مياه',
      category: DestinationCategory.facility,
      icon: Icons.wc_rounded,
      aliases: ['حمام', 'تواليت', 'دورة مياه', 'restroom', 'toilet'],
      isQuickShortcut: true,
    ),
    BuildingDestination(
      id: 'elevators',
      name: 'مصاعد',
      category: DestinationCategory.facility,
      icon: Icons.elevator_rounded,
      aliases: ['اسانسير', 'مصعد', 'elevator', 'lift'],
      isQuickShortcut: true,
    ),
    BuildingDestination(
      id: 'exits',
      name: 'مخارج',
      category: DestinationCategory.facility,
      icon: Icons.meeting_room_rounded,
      aliases: ['مخرج', 'خروج', 'exit'],
      isQuickShortcut: true,
    ),
    BuildingDestination(
      id: 'cafeteria',
      name: 'كافيتيريا',
      category: DestinationCategory.facility,
      icon: Icons.local_cafe_rounded,
      aliases: ['كافيه', 'مطعم', 'بوفيه', 'cafe', 'coffee'],
      isQuickShortcut: true,
    ),
  ];

  /// فروع دورات المياه حسب النوع — مبتظهرشي في صف الاختصارات السريعة مباشرة
  /// (isQuickShortcut: false لءنهم)، بيتعرضوا بس من خلال بوب اختيار
  /// بعد ما المستخدم يدوس على زرار "دورات مياه". لسه برض nodeID لحد
  /// ما تتضاف نقاط حقيقية لدورات المياه في خريطة المبنى.
  static const BuildingDestination restroomsMale = BuildingDestination(
    id: 'restrooms_male',
    name: 'دورات مياه (رجالي)',
    category: DestinationCategory.facility,
    icon: Icons.wc_rounded,
  );

  static const BuildingDestination restroomsFemale = BuildingDestination(
    id: 'restrooms_female',
    name: 'دورات مياه (حريمي)',
    category: DestinationCategory.facility,
    icon: Icons.wc_rounded,
  );
}
