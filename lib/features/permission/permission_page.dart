import 'package:parliament_ips/controllers/permission_controller.dart';
import 'package:parliament_ips/core/localization/locale_controller.dart';
import 'package:parliament_ips/core/theme/app_palette.dart';
import 'package:parliament_ips/core/theme/theme_controller.dart';
import 'package:parliament_ips/features/navigation/views/main_navigation_screen.dart';
import 'package:parliament_ips/features/onboarding/onboarding_page.dart';
import 'package:parliament_ips/features/permission/widgets/permission_checklist_card.dart';
import 'package:parliament_ips/features/permission/widgets/permission_status_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// أنواع حالات صفحة الأذونات — كل حالة بترسم واجهة مختلفة بنفس الصفحة.
enum _PermissionUiState {
  locationPermissionOnly, // صلاحية الموقع مرفوضة بس، البلوتوث والـ GPS تمام
  locationServiceOffOnly,  // خدمة الموقع (GPS) متوقفة بس، الصلاحيات والبلوتوث تمام
  bluetoothOffOnly,        // البلوتوث مقفول بس (adapter)، الموقع تمام
  checklist,               // أكتر من حاجة ناقصة
  allSet,                  // كل حاجة متفعّلة
}

/// صفحة الأذونات — صفحة واحدة بترسم نفسها بشكل مختلف حسب حالة الأذونات الحالية.
class PermissionPage extends StatelessWidget {
  final permissionController = Get.find<PermissionController>();

  PermissionPage({super.key});

  _PermissionUiState _resolveState() {
    final locationPermOk = permissionController.locationPermissionGranted.value;
    final locationServiceOk = permissionController.locationServiceEnabled.value;
    final bluetoothOk = permissionController.isBluetoothAdapterOn.value;

    if (locationPermOk && locationServiceOk && bluetoothOk) {
      return _PermissionUiState.allSet;
    }

    // لو ناقص فقط تشغيل الـ GPS (صلاحية الموقع ممنوحة والبلوتوث شغال)
    if (locationPermOk && !locationServiceOk && bluetoothOk) {
      return _PermissionUiState.locationServiceOffOnly;
    }

    // لو ناقص فقط تشغيل البلوتوث (صلاحية الموقع وخدمة الـ GPS تمام)
    if (locationPermOk && locationServiceOk && !bluetoothOk) {
      return _PermissionUiState.bluetoothOffOnly;
    }

    // لو ناقص فقط إذن صلاحية الموقع (البلوتوث شغال وخدمة الـ GPS تمام)
    if (!locationPermOk && locationServiceOk && bluetoothOk) {
      return _PermissionUiState.locationPermissionOnly;
    }

    return _PermissionUiState.checklist;
  }

  Future<void> _handleStartNavigation() async {
    await permissionController.checkPermissionStatus();
    if (permissionController.locationPermissionGranted.value == true &&
        permissionController.locationServiceEnabled.value == true &&
        permissionController.bluetoothStatus.value == true) {
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('initial') == true;
      if (onboardingDone) {
        Get.offAll(const MainNavigationScreen());
      } else {
        Get.offAll(OnboardingPage());
      }
    } else {
      Get.rawSnackbar(
        titleText: const Text(
          'Error',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        messageText: Text(
          'يرجى تفعيل الأذونات أعلاه.'.tr,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final localeController = Get.find<LocaleController>();

    return Obx(() {
      final palette = AppPalette.of(themeController.isDarkMode.value);
      final state = _resolveState();

      return Directionality(
        textDirection:
            localeController.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Center(
                child: SingleChildScrollView(
                  child: _buildForState(context, state, palette),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildForState(
    BuildContext context,
    _PermissionUiState state,
    AppPalette palette,
  ) {
    switch (state) {
      case _PermissionUiState.locationPermissionOnly:
        return PermissionStatusCard(
          palette: palette,
          illustrationIcon: Icons.location_on_rounded,
          badgeIcon: Icons.close_rounded,
          title: 'السماح مطلوب',
          description:
              'يبدو أنك لم تسمح للتطبيق بالوصول المطلوب. لتتمكن من استخدام التوجيه داخل المبنى، يرجى تفعيل الصلاحية من إعدادات التطبيق.',
          primaryButtonLabel: 'فتح الإعدادات',
          onPrimaryPressed: () => openAppSettings(),
          secondaryButtonLabel: 'حاول مرة أخرى',
          onSecondaryPressed: () => permissionController.checkPermissionStatus(),
        );

      case _PermissionUiState.locationServiceOffOnly:
        return PermissionStatusCard(
          palette: palette,
          illustrationIcon: Icons.location_on_rounded,
          toggleLabel: 'OFF',
          badgeIcon: Icons.location_off_rounded,
          title: 'الموقع متوقف',
          description:
              'يرجى سحب شريط الإشعارات من أعلى الشاشة وتفعيل الموقع (GPS) للمتابعة.',
          primaryButtonLabel: 'حاول مرة أخرى',
          onPrimaryPressed: () => permissionController.checkPermissionStatus(),
        );

      case _PermissionUiState.bluetoothOffOnly:
        return PermissionStatusCard(
          palette: palette,
          illustrationIcon: Icons.bluetooth_rounded,
          toggleLabel: 'OFF',
          badgeIcon: Icons.bluetooth_disabled_rounded,
          title: 'البلوتوث متوقف',
          description: 'قم بتشغيل البلوتوث للبحث عن إشارات التوجيه داخل المبنى.',
          primaryButtonLabel: 'تشغيل البلوتوث',
          onPrimaryPressed: () => permissionController.requestEnableBluetooth(),
          secondaryButtonLabel: 'حاول مرة أخرى',
          onSecondaryPressed: () => permissionController.checkPermissionStatus(),
        );

      case _PermissionUiState.checklist:
        final locationPermOk = permissionController.locationPermissionGranted.value;
        final locationServiceOk = permissionController.locationServiceEnabled.value;
        final bluetoothOk = permissionController.isBluetoothAdapterOn.value;

        return PermissionChecklistCard(
          palette: palette,
          title: 'هناك أذونات مطلوبة',
          description:
              'للاستمرار في استخدام التوجيه داخل المبني، يرجى تفعيل الأذونات التالية.',
          items: [
            PermissionChecklistItem(
              icon: Icons.gps_fixed_rounded,
              title: 'خدمة الموقع (GPS)',
              statusLabel: locationServiceOk ? 'مفعّل' : 'متوقف',
              isGranted: locationServiceOk,
            ),
            PermissionChecklistItem(
              icon: Icons.location_on_rounded,
              title: 'صلاحية الموقع',
              statusLabel: locationPermOk ? 'مفعّل' : 'غير مفعّلة',
              isGranted: locationPermOk,
              actionLabel: 'تشغيل',
              onAction: () async {
                final status = await Permission.location.request();
                if (status.isPermanentlyDenied) {
                  openAppSettings();
                } else {
                  await permissionController.checkPermissionStatus();
                }
              },
            ),
            PermissionChecklistItem(
              icon: Icons.bluetooth_rounded,
              title: 'البلوتوث',
              statusLabel: bluetoothOk ? 'مفعّل' : 'متوقف',
              isGranted: bluetoothOk,
              actionLabel: 'تشغيل',
              onAction: () => permissionController.requestEnableBluetooth(),
            ),
          ],
          onRetry: () => permissionController.checkPermissionStatus(),
        );

      case _PermissionUiState.allSet:
        return PermissionStatusCard(
          palette: palette,
          illustrationIcon: Icons.check_rounded,
          standalone: true,
          title: 'كل شيء جاهز',
          description:
              'تم تفعيل جميع الأذونات المطلوبة. يمكنك الآن استخدام التوجيه داخل المبنى.',
          primaryButtonLabel: 'ابدأ التوجيه',
          onPrimaryPressed: _handleStartNavigation,
        );
    }
  }
}
