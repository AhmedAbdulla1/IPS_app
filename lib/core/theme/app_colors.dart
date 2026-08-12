import 'package:flutter/material.dart';

/// ألوان هوية مجلس النواب المصري (ذهبي / بني / بيچ)
class AppColors {
  AppColors._();

  // خلفيات
  static const Color background = Color(0xFFEDE3D0);
  static const Color surface = Color(0xFFF5EEDE);

  // الذهبي (الأيقونات، السهم، الفواصل)
  static const Color gold = Color(0xFFC29B4E);
  static const Color goldLight = Color(0xFFE4D3A8);
  static const Color goldDark = Color(0xFF9C7A34);

  // البني الغامق (الأزرار، النصوص الأساسية)
  static const Color brownDark = Color(0xFF4A3623);
  static const Color brownMedium = Color(0xFF6B5439);

  // النصوص
  static const Color textPrimary = Color(0xFF3B2E1E);
  static const Color textSecondary = Color(0xFF8A7A5C);
  static const Color textOnDark = Color(0xFFF5EEDE);

  // عناصر الحالة
  static const Color statusGreen = Color(0xFF4CAF50);
  static const Color statusError = Color(0xFFA85C50);
  static const Color chipBackground = Color(0xFFF7F1E3);

  // ظلال
  static const Color shadow = Color(0x33000000);

  // ---- ثيم شاشة التوجيه النشط (Active Navigation) ----
  // بتتفعل بس لما isNavigating == true، ثيم غامق مطابق لصورة المرجع.
  static const Color navBackground = Color(0xFF141414);
  static const Color navSurface = Color(0xFF1E1E1E);
  static const Color navAccent = Color(0xFFF5A623);
  static const Color navAccentDark = Color(0xFFD98E12);
  static const Color navTextPrimary = Color(0xFFF5F5F5);
  static const Color navTextSecondary = Color(0xFF9A9A9A);
  static const Color navDotInactive = Color(0xFF4A4A4A);
  static const Color navSuccess = Color(0xFF3DDC84);
}
