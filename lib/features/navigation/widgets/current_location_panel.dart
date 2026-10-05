import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';

/// الحالة الابتدائية للشاشة: عرض موقع المستخدم الحالي (بدل سهم التوجيه).
class CurrentLocationPanel extends StatelessWidget {
  final String locationLabel;
  final bool isOutOfCoverage;
  final AppPalette palette;

  const CurrentLocationPanel({
    super.key,
    required this.locationLabel,
    this.isOutOfCoverage = false,
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
            colors: isOutOfCoverage
                ? [palette.brownDark, palette.goldDark.withValues(alpha: 0.7)]
                : [palette.brownDark, palette.goldDark],
          ).createShader(bounds),
          child: Icon(
            isOutOfCoverage
                ? Icons.wrong_location_rounded
                : Icons.person_pin_circle_rounded,
            size: 130,
            color: Colors.white,
            shadows: [
              Shadow(
                color: palette.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: palette.brownDark,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                isOutOfCoverage
                    ? 'تنبيه التغطية'.tr
                    : (locationLabel == 'جارِ تحديد موقعك...' ||
                            locationLabel == 'Locating your position...'
                        ? 'تحديد الموقع'.tr
                        : 'أنت الآن بالقرب من'.tr),
                style: TextStyle(
                  fontSize: 12,
                  color: isOutOfCoverage
                      ? palette.goldLight
                      : palette.textOnDark.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                locationLabel.tr,
                textAlign: TextAlign.center,
                style: AppTextStyles.directionInstruction.copyWith(
                  color: palette.textOnDark,
                  fontSize: 20,
                ),
              ),
              if (isOutOfCoverage) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: palette.goldLight.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_walk_rounded,
                        size: 20,
                        color: palette.goldLight,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'يرجى التحرك لأقرب ممر لالتقاط الإشارة'.tr,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: palette.textOnDark,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Mulish',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
