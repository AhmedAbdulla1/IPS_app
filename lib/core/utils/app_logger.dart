import 'package:flutter/foundation.dart';

/// أداة تسجيل الرسائل المركزية للتطبيق (Centralized Logger).
/// تضمن منع أي طباعة في الكونسول أثناء وضع الإصدار النهائي (Release Mode)،
/// وتسمح بالطباعة فقط أثناء وضع التطوير (Debug Mode).
class AppLogger {
  AppLogger._();

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  static void warn(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message: $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }
}
