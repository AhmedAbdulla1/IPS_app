/// المصدر الموحّد لمسارات كل الصور/الأيقونات/الـ GIFs المستخدمة في التطبيق.
/// أي أصل بصري جديد يتضاف هنا بدل ما يتكرر كـ String حرفي جوه الويدجتس،
/// عشان لو المسار اتغيّر يوم ما، يتغيّر من مكان واحد بس.
///
/// ملحوظة: مجلد assets/images/ كله متسجل في pubspec.yaml أصلاً
/// (`assets: - assets/images/`)، فأي صورة تتضاف جوا المجلد أو أي مجلد فرعي
/// منه بتشتغل تلقائيًا من غير ما تحتاج تعديل pubspec.yaml تاني.
class AppAssets {
  AppAssets._();

  static const String _base = 'assets/images';

  // ---- خلفيات الشاشة الرئيسية (بتتغيّر مع الوضع الليلي/النهاري) ----
  static const String backgroundLight = '$_base/background_light.png';
  static const String backgroundDark = '$_base/background_dark.png';

  // ---- الأيقونة الرئيسية ----
  static const String appIcon = '$_base/icon.png';

  // ---- GIFs تفاعلية ----
  static const String gifNavigationArrow = '$_base/arrow_animation.gif';
  static const String gifDestinationPin = '$_base/location_pin.gif';
  static const String gifCalibrate = '$_base/calibrate.gif';
  static const String gifElevatorUp = '$_base/elevator_up.gif';
  static const String gifElevatorDown = '$_base/elevator_down.gif';

  // ---- Vectors ----
  static const String vectorShadow = '$_base/vectors/vector_shadow.png';
  static const String vectorLoading = '$_base/vectors/vector_loading.gif';
  static const String vectorPermission = '$_base/vectors/vector_permission.gif';

  // ---- Splash ----
  static const String splashIcon = '$_base/splash/ic_splash.png';

  // ---- Onboarding ----
  static const String onboarding1 = '$_base/onboarding/onboarding_1.png';
  static const String onboarding2 = '$_base/onboarding/onboarding_2.png';
  static const String onboarding3 = '$_base/onboarding/onboarding_3.png';

}
