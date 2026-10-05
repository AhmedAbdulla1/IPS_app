import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';

/// شريحة حالة تحديد الموقع (نقطة خضراء + نص)
class LocationStatusChip extends StatelessWidget {
  final bool isDetermined;
  final bool isOutOfCoverage;
  final AppPalette palette;

  const LocationStatusChip({
    super.key,
    this.isDetermined = true,
    this.isOutOfCoverage = false,
    this.palette = AppPalette.light,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String statusText;

    if (isDetermined) {
      dotColor = palette.statusGreen;
      statusText = 'تم تحديد الموقع'.tr;
    } else if (isOutOfCoverage) {
      dotColor = Colors.orangeAccent;
      statusText = 'خارج التغطية'.tr;
    } else {
      dotColor = Colors.grey;
      statusText = 'جارِ تحديد الموقع...'.tr;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.chipBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: palette.shadow, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: AppTextStyles.statusChipText.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }
}
