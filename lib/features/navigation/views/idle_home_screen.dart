import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/current_location_panel.dart';
import '../widgets/facility_icon_button.dart';
import '../widgets/floor_badge.dart';
import '../widgets/location_status_chip.dart';
import '../widgets/navigation_start_button.dart';
import '../widgets/search_dropdown_field.dart';

/// الحالة الابتدائية للشاشة الرئيسية: البحث/الاختصارات + عرض الموقع الحالي.
/// بتستجيب لمفتاح الوضع الليلي في الإعدادات (ThemeController) وللغة
/// (LocaleController).
class IdleHomeScreen extends StatelessWidget {
  final NavigationScreenController controller;

  const IdleHomeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      final palette = AppPalette.of(themeController.isDarkMode.value);

      return GestureDetector(
        // تاچ في أي مكان فاضي بيقفل الدروب داون
        behavior: HitTestBehavior.translucent,
        onTap: controller.closeDropdown,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // 1) شريط البحث/المنيو (دروب داون ذكي)
                SearchDropdownField(controller: controller, palette: palette),

                const SizedBox(height: 20),

                // 2) صف أيقونات الاختصارات السريعة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: controller.quickShortcuts
                      .map(
                        (facility) => FacilityIconButton(
                          facility: facility,
                          palette: palette,
                          onTap: () => controller.onShortcutTap(facility),
                        ),
                      )
                      .toList(),
                ),

                const Spacer(),

                // 3) بانل الموقع الحالي
                Obx(
                  () => CurrentLocationPanel(
                    locationLabel: controller.currentLocationLabel.value,
                    palette: palette,
                  ),
                ),

                const SizedBox(height: 16),

                // 4) صف الحالة السفلي: تحديد الموقع + الدور
                Obx(
                  () => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LocationStatusChip(
                        isDetermined: controller.isLocationDetermined.value,
                        palette: palette,
                      ),
                      FloorBadge(floor: controller.currentFloor.value, palette: palette),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 5) زرار البدء
                Obx(
                  () => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NavigationStartButton(
                      enabled: controller.canStart,
                      onPressed: controller.onStartPressed,
                      palette: palette,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
