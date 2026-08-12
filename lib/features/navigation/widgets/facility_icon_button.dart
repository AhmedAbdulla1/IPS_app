import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/locale_controller.dart';
import '../models/navigation_destination.dart';

/// زرار دائري لاختصار سريع (دورات مياه / مصاعد / مخارج / كافيتيريا).
/// الضغط عليه بيبدأ التوجيه فورًا من غير الحاجة لزرار "بدء".
class FacilityIconButton extends StatelessWidget {
  final BuildingDestination facility;
  final VoidCallback? onTap;
  final AppPalette palette;

  const FacilityIconButton({
    super.key,
    required this.facility,
    this.onTap,
    this.palette = AppPalette.light,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: palette.shadow, blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(facility.icon, color: palette.goldDark, size: 26),
          ),
          const SizedBox(height: 6),
          Obx(
            () => Text(
              facility.localizedName(Get.find<LocaleController>().isArabic),
              style: AppTextStyles.facilityLabel.copyWith(color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
