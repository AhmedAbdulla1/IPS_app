import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';

/// بانل حالة المسار: تأكيد إنك ماشي صح + ستيبر تقدّم + معلومات إضافية — بيستجيب للثيم.
class RouteProgressPanel extends StatelessWidget {
  final bool isOnCorrectPath;
  final int totalSteps;
  final int currentStep;
  final String remainingDistanceLabel;
  final int targetFloor;
  final AppPalette palette;

  const RouteProgressPanel({
    super.key,
    required this.isOnCorrectPath,
    required this.totalSteps,
    required this.currentStep,
    required this.remainingDistanceLabel,
    required this.targetFloor,
    this.palette = AppPalette.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                (isOnCorrectPath ? 'أنت على الطريق الصحيح' : 'حاول ترجع للمسار').tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isOnCorrectPath ? Icons.check_circle_rounded : Icons.error_rounded,
                color: isOnCorrectPath ? palette.statusGreen : palette.gold,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),

          _ProgressStepper(total: totalSteps, current: currentStep, palette: palette),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoBlock(
                title: 'المسافة المتبقية'.tr,
                value: remainingDistanceLabel,
                palette: palette,
              ),
              _InfoBlock(
                title: 'الدور القادم'.tr,
                value: '$targetFloor',
                trailingIcon: Icons.chevron_left_rounded,
                palette: palette,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressStepper extends StatelessWidget {
  final int total;
  final int current;
  final AppPalette palette;

  const _ProgressStepper({required this.total, required this.current, required this.palette});

  @override
  Widget build(BuildContext context) {
    final dots = List.generate(total, (i) => i);
    return SizedBox(
      height: 24,
      child: Row(
        children: dots.expand((i) {
          final isCurrent = i == current;
          final isPast = i < current;
          final dot = Container(
            width: isCurrent ? 16 : 10,
            height: isCurrent ? 16 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isPast || isCurrent) ? palette.gold : palette.dotInactive,
              border: isCurrent ? Border.all(color: palette.background, width: 2) : null,
            ),
          );
          final isLast = i == dots.length - 1;
          return [
            dot,
            if (!isLast)
              Expanded(
                child: Container(
                  height: 2,
                  color: isPast ? palette.gold : palette.dotInactive,
                ),
              ),
          ];
        }).toList(),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final String value;
  final IconData? trailingIcon;
  final AppPalette palette;

  const _InfoBlock({
    required this.title,
    required this.value,
    required this.palette,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: TextStyle(fontSize: 10, color: palette.textSecondary)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingIcon != null) ...[
              Icon(trailingIcon, size: 14, color: palette.textSecondary),
              const SizedBox(width: 2),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
