import 'package:flutter/material.dart';
import 'app_colors.dart';

/// أنماط النصوص المستخدمة في شاشات التنقل
class AppTextStyles {
  AppTextStyles._();

  // ملاحظة: مفيش خط مخصص متضاف للمشروع لسه (زي Cairo/Tajawal).
  // لو حبيت تضيف واحد، حطه في pubspec.yaml وفعّل السطر ده.
  static const String? fontFamily = null;

  static const TextStyle logoTitleAr = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.brownDark,
    height: 1.3,
  );

  static const TextStyle logoSubtitleEn = TextStyle(
    fontFamily: fontFamily,
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 1.2,
  );

  static const TextStyle searchHint = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle facilityLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle directionInstruction = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnDark,
  );

  static const TextStyle statusChipText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle floorBadgeText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnDark,
  );

  static const TextStyle langToggle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.brownDark,
  );
}
