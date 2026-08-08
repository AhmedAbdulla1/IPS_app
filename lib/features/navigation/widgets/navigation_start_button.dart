import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';

/// زرار "بدء" — بيتفعّل بس لو فيه وجهة متاختارة من البحث أو المنيو.
class NavigationStartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final String label;
  final AppPalette palette;

  const NavigationStartButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.label = 'بدء التوجيه',
    this.palette = AppPalette.light,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: enabled ? palette.brownDark : palette.goldLight,
          borderRadius: BorderRadius.circular(24),
          boxShadow: enabled
              ? [BoxShadow(color: palette.shadow, blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Center(
          child: Text(
            label.tr,
            style: AppTextStyles.directionInstruction.copyWith(
              fontSize: 15,
              color: enabled ? palette.textOnDark : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
