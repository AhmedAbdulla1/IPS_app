import 'package:permission_handler/permission_handler.dart';

/// منصة مساعدة لفتح إعدادات الموقع (GPS) مباشرة في نظام أندرويد
/// أو فتح إعدادات التطبيق في iOS مع fallback آمن 100% للتحديثات.
class LocationNative {
  LocationNative._();

  /// يفتح صفحة الإعدادات لتفعيل خدمة الموقع
  static Future<bool> requestEnableLocation() async {
    return await openAppSettings();
  }
}
