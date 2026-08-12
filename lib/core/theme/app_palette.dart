import 'package:flutter/material.dart';
import 'app_colors.dart';

/// نسخة الوضع الليلي من [AppColors] — القيم دي مأخوذة بالظبط من صورة
/// مرجع شاشة التوجيه النشط اللي اتبعتت، عشان لما الوضع الليلي يتفعّل من
/// الإعدادات، كل الشاشات (الرئيسية + التوجيه النشط + الإعدادات) تتحول
/// لنفس المظهر الغامق ده سوا.
class AppColorsDark {
  AppColorsDark._();

  static const Color background = Color(0xFF141414);
  static const Color surface = Color(0xFF1E1E1E);

  static const Color gold = Color(0xFFF5A623);
  static const Color goldLight = Color(0xFFFFD48A);
  static const Color goldDark = Color(0xFFD98E12);

  // في الوضع الليلي، الأزرار/الشارات الرئيسية بتبقى بلون الذهبي (زي زرار
  // "إلغاء الملاحة" في صورة المرجع)، والنص فوقها غامق للتباين.
  static const Color brownDark = Color(0xFFF5A623);
  static const Color brownMedium = Color(0xFFD98E12);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9A9A9A);
  static const Color textOnDark = Color(0xFF141414);

  static const Color statusGreen = Color(0xFF3DDC84);
  static const Color statusError = Color(0xFFC97B6E);
  static const Color chipBackground = Color(0xFF1E1E1E);

  static const Color dotInactive = Color(0xFF4A4A4A);

  static const Color shadow = Color(0x66000000);
}

/// مجموعة ألوان موحّدة (فاتح/غامق) بتتمرر للويدجتس بدل ما كل ويدجت
/// يقرا AppColors مباشرة — عشان كل شاشات التطبيق (الرئيسية، التوجيه
/// النشط، الإعدادات) تقدر تستجيب لمفتاح الوضع الليلي في صفحة الإعدادات.
class AppPalette {
  final Color background;
  final Color surface;
  final Color gold;
  final Color goldLight;
  final Color goldDark;
  final Color brownDark;
  final Color brownMedium;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnDark;
  final Color statusGreen;
  final Color statusError;
  final Color chipBackground;
  final Color dotInactive;
  final Color shadow;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.gold,
    required this.goldLight,
    required this.goldDark,
    required this.brownDark,
    required this.brownMedium,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnDark,
    required this.statusGreen,
    required this.statusError,
    required this.chipBackground,
    required this.dotInactive,
    required this.shadow,
  });

  static const light = AppPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    gold: AppColors.gold,
    goldLight: AppColors.goldLight,
    goldDark: AppColors.goldDark,
    brownDark: AppColors.brownDark,
    brownMedium: AppColors.brownMedium,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textOnDark: AppColors.textOnDark,
    statusGreen: AppColors.statusGreen,
    statusError: AppColors.statusError,
    chipBackground: AppColors.chipBackground,
    dotInactive: AppColors.goldLight,
    shadow: AppColors.shadow,
  );

  static const dark = AppPalette(
    background: AppColorsDark.background,
    surface: AppColorsDark.surface,
    gold: AppColorsDark.gold,
    goldLight: AppColorsDark.goldLight,
    goldDark: AppColorsDark.goldDark,
    brownDark: AppColorsDark.brownDark,
    brownMedium: AppColorsDark.brownMedium,
    textPrimary: AppColorsDark.textPrimary,
    textSecondary: AppColorsDark.textSecondary,
    textOnDark: AppColorsDark.textOnDark,
    statusGreen: AppColorsDark.statusGreen,
    statusError: AppColorsDark.statusError,
    chipBackground: AppColorsDark.chipBackground,
    dotInactive: AppColorsDark.dotInactive,
    shadow: AppColorsDark.shadow,
  );

  static AppPalette of(bool isDark) => isDark ? dark : light;
}
