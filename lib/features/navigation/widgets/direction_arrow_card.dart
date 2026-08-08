import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// بطاقة الاتجاه: سهم كبير + شريط تعليمات سفلي (زي "انعطف يسار")
class DirectionArrowCard extends StatelessWidget {
  final String instruction;
  final DirectionType direction;

  const DirectionArrowCard({
    super.key,
    required this.instruction,
    this.direction = DirectionType.left,
  });

  IconData get _arrowIcon {
    switch (direction) {
      case DirectionType.left:
        return Icons.turn_left_rounded;
      case DirectionType.right:
        return Icons.turn_right_rounded;
      case DirectionType.straight:
        return Icons.straight_rounded;
      case DirectionType.uTurn:
        return Icons.u_turn_left_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // السهم الكبير
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.goldLight, AppColors.goldDark],
          ).createShader(bounds),
          child: Icon(
            _arrowIcon,
            size: 130,
            color: Colors.white,
            shadows: [
              Shadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // شريط التعليمات
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.brownDark,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(instruction, style: AppTextStyles.directionInstruction),
          ),
        ),
      ],
    );
  }
}

enum DirectionType { left, right, straight, uTurn }
