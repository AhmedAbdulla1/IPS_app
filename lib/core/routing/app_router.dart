import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parliament_ips/features/onboarding/first_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/permission_controller.dart';
import '../../features/navigation/views/main_navigation_screen.dart';
import '../../features/permission/permission_page.dart';

/// مسؤول عن تحديد أول شاشة يراها المستخدم عند فتح التطبيق.
///
/// منطق القرار:
/// ┌─ onboarding مكتمل (initial == true)
/// │    └→ PermissionPage → MainNavigationScreen
/// └─ أول مرة يفتح التطبيق (initial == null/false)
///      └→ PermissionPage → OnboardingPage → MainNavigationScreen
///
/// لا يوجد splash screen هنا — الـ native splash (flutter_native_splash)
/// يُغطي فترة تحميل الـ services في main().
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  /// تُحمَّل مرة واحدة في initState قبل بناء أي widget.
  late final Future<Widget> _startScreenFuture;

  @override
  void initState() {
    super.initState();
    _startScreenFuture = _resolveStartScreen();
  }

  /// يقرر الشاشة المناسبة بناءً على حالة الـ onboarding وصلاحيات الـ BLE.
  Future<Widget> _resolveStartScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('initial') == true;

    final permController = Get.find<PermissionController>();
    await permController.checkPermissionStatus();

    final permissionsOk = permController.locationPermissionGranted.value &&
        permController.locationServiceEnabled.value &&
        permController.bluetoothStatus.value;

    // لو الصلاحيات ناقصة → PermissionPage دائمًا أول ما نشوفه
    if (!permissionsOk) {
      return PermissionPage();
    }

    // الصلاحيات موجودة:

   // todo : change
    if (!onboardingDone) {
      return FirstPage();
    }

    return const MainNavigationScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _startScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // فترة انتقالية قصيرة جدًا — الـ native splash يغطيها
          return const SizedBox.shrink();
        }
        return snapshot.data!;
      },
    );
  }
}
