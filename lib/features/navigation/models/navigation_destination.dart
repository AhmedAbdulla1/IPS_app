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

  String get englishLabel {
    switch (this) {
      case DestinationCategory.hall:
        return 'Halls';
      case DestinationCategory.office:
        return 'Offices';
      case DestinationCategory.service:
        return 'Services';
      case DestinationCategory.facility:
        return 'Facilities';
    }
  }

  /// العنوان المعروض حسب لغة الواجهة الحالية.
  String localizedLabel(bool isArabic) => isArabic ? arabicLabel : englishLabel;
}

/// وجهة داخل خريطة المبنى (قاعة / مكتب / خدمة / مرفق سريع)
///
/// ملاحظة تسمية: الاسم مش "NavigationDestination" عشان فليتر نفسه عنده
/// كلاس بنفس الاسم بالظبط جوه material.dart (بتاع NavigationBar)، وأي
/// ملف بيعمل import لـ material.dart + الموديل ده مع بعض كان بيدّي
/// "ambiguous_import". BuildingDestination بيتجنب التصادم من الأساس.
///
/// ملاحظة ثنائية اللغة: الاسم بقى مقسوم [nameAr]/[nameEn] بدل حقل واحد
/// (كان اسمه `name`)، عشان الأماكن الحقيقية الجاية من Supabase
/// (nodes.name_ar / nodes.name_en) تقدر تتعرض صح في الحالتين. استخدم
/// [localizedName] في أي مكان في الـ UI بدل ما تقرا حقل خام مباشرة.
class BuildingDestination {
  final String id;
  final String nameAr;
  final String? nameEn;
  final DestinationCategory category;
  final IconData icon;

  /// كلمات بديلة/مرادفات بتساعد البحث الذكي يلاقي النتيجة — ممكن تحتوي
  /// عربي وإنجليزي مع بعض في نفس القائمة (زي ما بيجي من node_aliases).
  final List<String> aliases;

  /// لو true، المكان ده بيظهر كزرار اختصار سريع تحت شريط البحث.
  final bool isQuickShortcut;

  /// نود التوجيه الحقيقي (nodeID في BuildingGraph/BeaconController.poiList)
  /// اللي الوجهة دي بتتحل ليه فعليًا لحساب المسار (A*). لو null، معناها
  /// لسه مفيش نود حقيقي مرتبط بالوجهة دي، وNavigationScreenController
  /// بيتشيك على القيمة دي قبل ما يحاول يبدأ توجيه ليها.
  final int? nodeID;

  /// لو الوجهة دي زرار اختصار سريع، نوع الاختصار المقابل في عمود
  /// destinations.shortcut_type (زي 'elevator'، 'restroom_male') — بيُستخدم
  /// لاختيار "أقرب" وجهة حقيقية مطابقة وقت الضغط، لأن فيه أكتر من
  /// أسانسير/حمام واحد في المبنى عادةً.
  final String? shortcutType;

  const BuildingDestination({
    required this.id,
    required this.nameAr,
    this.nameEn,
    required this.category,
    required this.icon,
    this.aliases = const [],
    this.isQuickShortcut = false,
    this.nodeID,
    this.shortcutType,
  });

  /// الاسم المعروض حسب لغة الواجهة الحالية. بيرجع للعربي تلقائيًا لو
  /// مفيش نسخة إنجليزية متسجّلة لسه للمكان ده (بدل ما يظهر فاضي).
  String localizedName(bool isArabic) {
    if (!isArabic && nameEn != null && nameEn!.trim().isNotEmpty) {
      return nameEn!;
    }
    return nameAr;
  }
}

/// الاختصارات السريعة الثابتة (أيقونات تحت شريط البحث).
/// دي مرافق عامة لسه مفيش لها نقاط (nodeID) في خريطة المبنى الحقيقية —
/// بمجرد ما تتضاف نقاط دورات مياه/مصاعد/مخارج/كافيتيريا فعلية في
/// خريطة المبنى، حط nodeID هنا وهيشتغلوا فورًا.
class NavigationDestinationsData {
  NavigationDestinationsData._();

  static const List<BuildingDestination> quickShortcuts = [
    BuildingDestination(
      id: 'restrooms',
      nameAr: 'دورات مياه',
      nameEn: 'Restrooms',
      category: DestinationCategory.facility,
      icon: Icons.wc_rounded,
      aliases: ['حمام', 'تواليت', 'دورة مياه', 'restroom', 'toilet','wc','WC',],
      isQuickShortcut: true,
    ),
    BuildingDestination(
      id: 'elevators',
      nameAr: 'مصاعد',
      nameEn: 'Elevators',
      category: DestinationCategory.facility,
      icon: Icons.elevator_rounded,
      aliases: ['اسانسير', 'مصعد', 'elevator', 'lift'],
      isQuickShortcut: true,
      shortcutType: 'elevator',
    ),
    // BuildingDestination(
    //   id: 'exits',
    //   nameAr: 'مخارج',
    //   nameEn: 'Exits',
    //   category: DestinationCategory.facility,
    //   icon: Icons.meeting_room_rounded,
    //   aliases: ['مخرج', 'خروج', 'exit'],
    //   isQuickShortcut: true,
    //   shortcutType: 'exit',
    // ),
    // BuildingDestination(
    //   id: 'cafeteria',
    //   nameAr: 'كافيتيريا',
    //   nameEn: 'Cafeteria',
    //   category: DestinationCategory.facility,
    //   icon: Icons.local_cafe_rounded,
    //   aliases: ['كافيه', 'مطعم', 'بوفيه', 'cafe', 'coffee'],
    //   isQuickShortcut: true,
    //   shortcutType: 'cafeteria',
    // ),
  ];

  /// فروع دورات المياه حسب النوع — مبتظهرشي في صف الاختصارات السريعة مباشرة
  /// (isQuickShortcut: false)، بيتعرضوا بس من خلال بوب اختيار بعد ما
  /// المستخدم يدوس على زرار "دورات مياه". لسه برضه nodeID لحد ما تتضاف
  /// نقاط حقيقية لدورات المياه في خريطة المبنى.
  static const BuildingDestination restroomsMale = BuildingDestination(
    id: 'restrooms_male',
    nameAr: 'دورات مياه (رجالي)',
    nameEn: 'Restrooms (Male)',
    category: DestinationCategory.facility,
    icon: Icons.wc_rounded,
    shortcutType: 'restroom_male',
  );

  static const BuildingDestination restroomsFemale = BuildingDestination(
    id: 'restrooms_female',
    nameAr: 'دورات مياه (حريمي)',
    nameEn: 'Restrooms (Female)',
    category: DestinationCategory.facility,
    icon: Icons.wc_rounded,
    shortcutType: 'restroom_female',
  );
}
