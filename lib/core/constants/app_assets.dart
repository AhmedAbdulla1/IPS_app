/// المصدر الموحّد لمسارات كل الصور المستخدمة في التطبيق.
/// أي أصل بصري جديد يتضاف هنا بدل ما يتكرر كـ String حرفي جوه الويدجتس،
/// عشان لو المسار اتغيّر يوم ما، يتغيّر من مكان واحد بس.
class AppAssets {
  AppAssets._();

  static const String _base = 'assets/images';

  // ---- خلفيات الشاشة الرئيسية (بتتغيّر مع الوضع الليلي/النهاري) ----
  static const String backgroundLight = '$_base/background_light.png';
  static const String backgroundDark = '$_base/background_dark.png';

  // ---- الأيقونة الرئيسية ----
  static const String appIcon = '$_base/icon.png';

  // ---- Onboarding ----
  static const String onboarding1 = '$_base/onboarding/onboarding_1.png';
  static const String onboarding2 = '$_base/onboarding/onboarding_2.png';
  static const String onboarding3 = '$_base/onboarding/onboarding_3.png';
}
