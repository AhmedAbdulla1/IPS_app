import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';

enum DirectionType { left, right, straight, uTurn, up, down, arrived }

/// السهم الكبير + نص التعليمات (شاشة التوجيه النشط) — بيستجيب للثيم.
///
/// الرمز الرئيسي بيتغيّر حسب نوع الخطوة:
/// - يمين/يسار/مستقيم/استدارة → السهم بيتدوّر بزاوية الاتجاه (زي ما كان).
/// - صعود/نزول دور (أسانسير أو سلم) → أيقونة أسانسير + بادچ صغير سهم
///   لأعلى/لأسفل، بدل السهم، عشان توضح إنها مش خطوة مشي عادية.
/// - وصلت للوجهة → أيقونة صح خضرا، بدون دوران، بدل السهم.
class DirectionHero extends StatelessWidget {
  final DirectionType direction;
  final String instruction;
  final String subInstruction;
  final AppPalette palette;

  const DirectionHero({
    super.key,
    required this.direction,
    required this.instruction,
    required this.subInstruction,
    this.palette = AppPalette.dark,
  });

  double get _angle {
    switch (direction) {
      case DirectionType.left:
        return -0.78539816; // -45°
      case DirectionType.right:
        return 0.78539816; // 45°
      case DirectionType.straight:
        return 0;
      case DirectionType.uTurn:
        return 3.14159265; // 180°
      case DirectionType.up:
      case DirectionType.down:
      case DirectionType.arrived:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildIcon(),
        const SizedBox(height: 16),
        Text(
          instruction.tr,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subInstruction.tr,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildIcon() {
    switch (direction) {
      case DirectionType.arrived:
        return Icon(
          Icons.check_circle_rounded,
          size: 110,
          color: palette.statusGreen,
        );

      case DirectionType.up:
      case DirectionType.down:
        return SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.elevator_rounded, size: 110, color: palette.gold),
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.gold,
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadow,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    direction == DirectionType.up
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 20,
                    color: palette.textOnDark,
                  ),
                ),
              ),
            ],
          ),
        );

      case DirectionType.left:
      case DirectionType.right:
      case DirectionType.straight:
      case DirectionType.uTurn:
        return Transform.rotate(
          angle: _angle,
          child: Icon(Icons.navigation_rounded, size: 110, color: palette.gold),
        );
    }
  }
}
