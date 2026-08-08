import 'package:pathfinder/controllers/permission_controller.dart';
import 'package:pathfinder/features/navigation/views/main_navigation_screen.dart';
import 'package:pathfinder/utils/size_config.dart';
import 'package:pathfinder/views/onboarding_page.dart';
import 'package:pathfinder/views/permission_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs app initialization (permission/Bluetooth check, shared prefs read)
/// while the native splash screen stays on screen, then navigates to the
/// right first page and removes the splash.
///
/// The native splash (configured via the `flutter_native_splash` section
/// in pubspec.yaml, generated into Android/iOS native resources by
/// `dart run flutter_native_splash:create`) is preserved past Flutter's
/// first frame by `FlutterNativeSplash.preserve()` in main.dart, so the
/// user keeps seeing it -- not this widget's (empty) build() -- until
/// [_initialize] below finishes.
class SplashScreenPage extends StatefulWidget {
  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage> {
  final permissionController = Get.find<PermissionController>();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    await permissionController.checkPermissionStatus();

    if (!mounted) return;

    final Widget nextPage;
    if (permissionController.locationPermissionGranted.value == false ||
        permissionController.bluetoothStatus.value == false) {
      nextPage = PermissionPage();
    } else if (prefs.getBool('initial') == true) {
      // الصفحة الرئيسية الجديدة (features/navigation) — بديل SelectionPage القديمة
      nextPage = const MainNavigationScreen();
    } else {
      nextPage = OnboardingPage();
    }

    Get.offAll(nextPage);

    // Removed only once the next page has been handed to Get.offAll, so
    // the native splash stays up right until the real first frame is
    // ready, rather than exposing a blank/default-themed frame in between.
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    // SizeConfig holds its screen-size data in static fields that most
    // other pages (e.g. SelectionPage) read from without ever calling
    // init() themselves -- they rely on this first build() doing it once,
    // app-wide, before any navigation happens. This mirrors what the old
    // AnimatedSplashScreen-based implementation did in its own build().
    SizeConfig().init(context);

    // The native splash is what's actually visible during _initialize();
    // this just needs to avoid painting anything jarring behind/under it.
    return const Scaffold(
      backgroundColor: Colors.white,
    );
  }
}
