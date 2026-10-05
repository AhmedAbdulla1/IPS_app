import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بيتحكم في لغة التطبيق (عربي/إنجليزي) عبر GetX.
/// الحالة بتتحفظ في shared_preferences وبترجع تلقائيًا أول ما التطبيق يفتح.
class LocaleController extends GetxController {
  static const _prefsKey = 'locale_code';

  static const Locale arabic = Locale('ar', 'EG');
  static const Locale english = Locale('en', 'US');

  final Rx<Locale> locale = arabic.obs;

  bool get isArabic => locale.value.languageCode == 'ar';

  @override
  void onInit() {
    super.onInit();
    _loadPersisted();
  }

  /// بيتستنى لحد ما يخلص تحميل اللغة المحفوظة — استخدمها قبل ‏`runApp`.
  Future<void> ensureLoaded() => _loadPersisted();

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      if (code == 'en') {
        locale.value = english;
        Get.updateLocale(english);
      } else {
        locale.value = arabic;
        Get.updateLocale(arabic);
      }
    } else {
      // اللغة الافتراضية دائماً هي العربية حتى لو لغة الجهاز إنجليزية
      locale.value = arabic;
      Get.updateLocale(arabic);
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    locale.value = newLocale;
    Get.updateLocale(newLocale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, newLocale.languageCode);
  }

  Future<void> toggleLocale() {
    return setLocale(isArabic ? english : arabic);
  }
}
