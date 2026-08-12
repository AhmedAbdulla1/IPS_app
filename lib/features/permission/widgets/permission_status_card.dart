import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import 'permission_illustration.dart';

/// كارت الحالة المفردة — بيتعرض لما فيه مشكلة واحدة بس (الموقع مرفوض، أو
/// البلوتوث مقفول)، أو لما كل حاجة تمام. بيتحكم فيه بالكامل عن طريق
/// الـ props عشان يغطي الثلاث حالات دول من غير تكرار كود.
class PermissionStatusCard extends StatelessWidget {
  final AppPalette palette;
  final IconData illustrationIcon;
  final IconData? badgeIcon;
  final Color? badgeColor;
  final String? toggleLabel;
  final bool standalone;
  final String title;
  final String description;
  final String primaryButtonLabel;
  final VoidCallback onPrimaryPressed;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;

  const PermissionStatusCard({
    super.key,
    required this.palette,
    required this.illustrationIcon,
    required this.title,
    required this.description,
    required this.primaryButtonLabel,
    required this.onPrimaryPressed,
    this.badgeIcon,
    this.badgeColor,
    this.toggleLabel,
    this.standalone = false,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PermissionIllustration(
          palette: palette,
          centerIcon: illustrationIcon,
          badgeIcon: badgeIcon,
          badgeColor: badgeColor,
          toggleLabel: toggleLabel,
          standalone: standalone,
        ),
        const SizedBox(height: 28),
        Text(
          title.tr,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        _Divider(palette: palette),
        const SizedBox(height: 14),
        Text(
          description.tr,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.6,
            color: palette.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPrimaryPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.brownDark,
              foregroundColor: palette.textOnDark,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              primaryButtonLabel.tr,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (secondaryButtonLabel != null) ...[
          const SizedBox(height: 14),
          TextButton(
            onPressed: onSecondaryPressed,
            child: Text(
              secondaryButtonLabel!.tr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final AppPalette palette;

  const _Divider({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.diamond, size: 6, color: palette.gold),
        ),
        _line(),
      ],
    );
  }

  Widget _line() => Container(width: 36, height: 1, color: palette.goldLight);
}
