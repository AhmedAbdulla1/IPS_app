import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';

/// شريحة حالة تحديد الموقع (نقطة خضراء + نص)
class LocationStatusChip extends StatelessWidget {
  final bool isDetermined;
  final AppPalette palette;

  const LocationStatusChip({
    super.key,
    this.isDetermined = true,
    this.palette = AppPalette.light,
  });

  @override
  Widget build(BuildContext context) {
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
              color: isDetermined ? palette.statusGreen : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            (isDetermined ? 'تم تحديد الموقع' : 'جارِ تحديد الموقع...').tr,
            style: AppTextStyles.statusChipText.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }
}
