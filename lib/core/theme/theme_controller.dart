import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بيتحكم في الوضع الليلي/النهاري لشاشات Idle + Settings
/// (شاشة التوجيه النشط دايمًا غامقة بتصميمها، مش متأثرة بالمفتاح ده).
///
/// الحالة بتتحفظ في shared_preferences وبترجع تلقائيًا أول ما التطبيق يفتح.
class ThemeController extends GetxController {
  static const _prefsKey = 'is_dark_mode';

  final RxBool isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadPersisted();
  }

  /// بيتستنى لحد ما يخلص تحميل القيمة المحفوظة — استخدمها قبل ‏`runApp`
  /// عشان الشاشة الأولى تفتح بالوضع الصح من غير "فلاش" للوضع الافتراضي.
  Future<void> ensureLoaded() => _loadPersisted();

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool(_prefsKey) ?? false;
    _updateThemeMode();
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;
    _updateThemeMode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  Future<void> toggleDarkMode() => setDarkMode(!isDarkMode.value);

  void _updateThemeMode() {
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }
}
