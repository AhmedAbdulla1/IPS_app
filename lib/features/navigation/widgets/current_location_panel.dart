import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';

/// الحالة الابتدائية للشاشة: عرض موقع المستخدم الحالي (بدل سهم التوجيه).
class CurrentLocationPanel extends StatelessWidget {
  final String locationLabel;
  final AppPalette palette;

  const CurrentLocationPanel({
    super.key,
    required this.locationLabel,
    this.palette = AppPalette.light,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.goldLight, palette.goldDark],
          ).createShader(bounds),
          child: Icon(
            Icons.person_pin_circle_rounded,
            size: 130,
            color: Colors.white,
            shadows: [Shadow(color: palette.shadow, blurRadius: 10, offset: const Offset(0, 4))],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: palette.brownDark,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: palette.shadow, blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Text(
                'أنت الآن في'.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.goldLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                locationLabel.tr,
                style: AppTextStyles.directionInstruction.copyWith(color: palette.textOnDark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
