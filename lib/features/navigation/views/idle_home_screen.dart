import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/current_location_panel.dart';
import '../widgets/facility_icon_button.dart';
import '../widgets/floor_badge.dart';
import '../widgets/location_status_chip.dart';
import '../widgets/navigation_start_button.dart';
import '../widgets/search_dropdown_field.dart';

/// محتوى (Body) الحالة الابتدائية للشاشة الرئيسية: البحث/الاختصارات + عرض
/// الموقع الحالي. الـ Scaffold والـ AppBar مملوكين لـ [MainNavigationScreen]
/// اللي بيستدعي الويدجت ده — عشان يبقى فيه خلفية واحدة موحّدة للشاشة كلها.
///
/// ترتيب الويدجت اتحدد بناءً على أكتر العناصر استخدامًا:
/// 1) البحث/المنيو + الاختصارات السريعة في الأعلى (الأكثر استخدامًا)
/// 2) منطقة المحتوى الوسطى: بانل الموقع الحالي
/// 3) صف الحالة (تحديد الموقع + الدور)
/// 4) زرار البدء في الأسفل (لما يبقى فيه اختيار من البحث/المنيو)
class IdleHomeScreen extends StatelessWidget {
  final NavigationScreenController controller;
  final AppPalette palette;

  const IdleHomeScreen({super.key, required this.controller, required this.palette});

  @override
  Widget build(BuildContext context) {
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
                        onTap: () => facility.id == 'restrooms'
                            ? _showRestroomGenderPopup(context)
                            : controller.onShortcutTap(facility),
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
  }

  /// بوب اختيار نوع دورات المياه (رجالي/حريمي) قبل ما نبدأ التوجيه.
  void _showRestroomGenderPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: palette.shadow, blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'دورات مياه'.tr,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اختر النوع'.tr,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _GenderOptionButton(
                        label: 'رجالي'.tr,
                        icon: Icons.man_rounded,
                        palette: palette,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          controller.selectRestroomVariant(isMale: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GenderOptionButton(
                        label: 'حريمي'.tr,
                        icon: Icons.woman_rounded,
                        palette: palette,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          controller.selectRestroomVariant(isMale: false);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GenderOptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppPalette palette;
  final VoidCallback onTap;

  const _GenderOptionButton({
    required this.label,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.goldLight, width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: palette.goldDark, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
