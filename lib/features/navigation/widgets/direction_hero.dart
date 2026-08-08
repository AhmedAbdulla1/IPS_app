import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';

enum DirectionType { left, right, straight, uTurn }

/// السهم الكبير + نص التعليمات (شاشة التوجيه النشط) — بيستجيب للثيم.
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Transform.rotate(
          angle: _angle,
          child: Icon(Icons.navigation_rounded, size: 110, color: palette.gold),
        ),
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
}
