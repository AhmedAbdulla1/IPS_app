import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';

/// مفتاح تبديل مرئي
class VisualToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final AppPalette palette;

  const VisualToggleSwitch({
    super.key, 
    required this.value,
    required this.palette,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onChanged != null) {
          onChanged!(!value);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? palette.brownDark : palette.goldLight,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: value ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
