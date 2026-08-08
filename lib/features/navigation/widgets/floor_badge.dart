import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';

/// شارة الدور الحالي (زي "الدور 1")
class FloorBadge extends StatelessWidget {
  final int floor;
  final VoidCallback? onTap;
  final AppPalette palette;

  const FloorBadge({
    super.key,
    required this.floor,
    this.onTap,
    this.palette = AppPalette.light,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: palette.brownDark,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: palette.shadow, blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الدور @n'.trParams({'n': '$floor'}),
              style: AppTextStyles.floorBadgeText.copyWith(color: palette.textOnDark),
            ),
            const SizedBox(width: 8),
            Icon(Icons.layers_rounded, color: palette.textOnDark, size: 18),
          ],
        ),
      ),
    );
  }
}
