import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parliament_ips/utils/constants.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/localization/locale_controller.dart';
import '../../calibration/calibration_page.dart';
import '../../navigation/controllers/app_tour_controller.dart';
import '../widgets/settings_tile.dart';
import '../widgets/visual_toggle_switch.dart';

/// شاشة الإعدادات — بتستجيب للوضع الليلي عن طريق AppPalette
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final localeController = Get.find<LocaleController>();

    return Obx(() {
      final palette = AppPalette.of(themeController.isDarkMode.value);

      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_forward, color: palette.textPrimary),
          ),
          title: Text(
            'الإعدادات'.tr,
            style: AppTextStyles.logoTitleAr.copyWith(color: palette.brownDark),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // زر اللغة
              SettingsTile(
                icon: Icons.language_rounded,
                title: 'اللغة'.tr,
                subtitle: localeController.isArabic ? 'العربية'.tr : 'English',
                palette: palette,
                trailing: Icon(
                  Icons.chevron_left_rounded,
                  color: palette.textSecondary,
                ),
                onTap: () {
                  _showLanguageBottomSheet(context, localeController, palette);
                },
              ),
              const SizedBox(height: 14),

              // زر المود (ليلي/نهاري)
              SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'الوضع الليلي'.tr,
                subtitle: 'تفعيل المظهر الداكن'.tr,
                palette: palette,
                trailing: VisualToggleSwitch(
                  value: themeController.isDarkMode.value,
                  palette: palette,
                  onChanged: (value) {
                    themeController.setDarkMode(value);
                  },
                ),
              ),
              const SizedBox(height: 14),

              // زر إعداد البوصلة
              SettingsTile(
                icon: Icons.explore_outlined,
                title: 'إعداد البوصلة'.tr,
                subtitle: 'معايرة اتجاه البوصلة'.tr,
                palette: palette,
                trailing: Icon(
                  Icons.chevron_left_rounded,
                  color: palette.textSecondary,
                ),
                onTap: () {
                  Get.to(() => CalibrationPage(
                    caliType: CaliType.setting,
                  ));
                },
              ),
              const SizedBox(height: 14),

              // زر الجولة التعريفية
              SettingsTile(
                icon: Icons.explore_outlined,
                title: 'جولة في التطبيق'.tr,
                subtitle: 'دليل تفاعلي لشرح عناصر الشاشة الرئيسية'.tr,
                palette: palette,
                trailing: Icon(
                  Icons.chevron_left_rounded,
                  color: palette.textSecondary,
                ),
                onTap: () {
                  Navigator.of(context).maybePop();
                  if (Get.isRegistered<AppTourController>()) {
                    Get.find<AppTourController>().requestTourReplay();
                  }
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showLanguageBottomSheet(
    BuildContext context,
    LocaleController localeController,
    AppPalette palette,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر اللغة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.textPrimary,
                fontFamily: 'Mulish',
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: Text(
                'العربية',
                style: TextStyle(color: palette.textPrimary, fontFamily: 'Mulish'),
              ),
              trailing: localeController.isArabic
                  ? Icon(Icons.check, color: palette.brownDark)
                  : null,
              onTap: () {
                localeController.setLocale(LocaleController.arabic);
                Get.back();
              },
            ),
            ListTile(
              title: Text(
                'English',
                style: TextStyle(color: palette.textPrimary, fontFamily: 'Mulish'),
              ),
              trailing: !localeController.isArabic
                  ? Icon(Icons.check, color: palette.brownDark)
                  : null,
              onTap: () {
                localeController.setLocale(LocaleController.english);
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }
}
