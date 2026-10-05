import 'package:flutter/services.dart';

/// يحدد فلافور التطبيق المشغل حالياً (إنتاج أو اختبار)
enum AppFlavor {
  production,
  test,
}

/// إدارة مركزية لحالة الفلافور بناءً على [appFlavor] من منصة فلاتر
class AppFlavorConfig {
  AppFlavorConfig._();

  static AppFlavor currentFlavor = AppFlavor.production;

  static bool get isTest => currentFlavor == AppFlavor.test;
  static bool get isProduction => currentFlavor == AppFlavor.production;

  /// يُستدعى مرة واحدة في بداية main() لقراءة الفلافور من المنصة
  static void initialize() {
    // appFlavor يأتي من package:flutter/services.dart ويحمل اسم الفلافور الممرر في --flavor
    if (appFlavor == 'qa' || appFlavor == 'test' || appFlavor == 'dev' || appFlavor == 'field') {
      currentFlavor = AppFlavor.test;
    } else {
      currentFlavor = AppFlavor.production;
    }
  }
}
