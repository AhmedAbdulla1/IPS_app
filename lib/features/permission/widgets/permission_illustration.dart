import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';

/// الرسمة التوضيحية العلوية في صفحة الأذونات: موبايل جوه دايرة خلفية ناعمة،
/// أيقونة رئيسية في نص الشاشة، وبادچ صغير (X / بلوتوث متوقف / صح) في الركن.
///
/// [standalone] بيشيل شكل الموبايل خالص ويسيب بس دايرة كبيرة بالأيقونة
/// جوّاها — مستخدم في حالة "كل شيء جاهز" (مفيش موبايل في الصورة المرجعية).
class PermissionIllustration extends StatelessWidget {
  final AppPalette palette;
  final IconData centerIcon;
  final IconData? badgeIcon;
  final Color? badgeColor;
  final String? toggleLabel;
  final bool standalone;

  const PermissionIllustration({
    super.key,
    required this.palette,
    required this.centerIcon,
    this.badgeIcon,
    this.badgeColor,
    this.toggleLabel,
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الدايرة الخلفية الناعمة
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.goldLight.withOpacity(0.25),
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.goldLight.withOpacity(0.6),
                width: 1.2,
              ),
            ),
          ),

          if (standalone)
            _StandaloneCheck(palette: palette, icon: centerIcon)
          else
            _PhoneFrame(
              palette: palette,
              centerIcon: centerIcon,
              toggleLabel: toggleLabel,
            ),

          // البادچ العلوي (X / بلوتوث متوقف)
          if (badgeIcon != null)
            Positioned(
              top: 28,
              right: 40,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (badgeColor ?? palette.statusError),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(badgeIcon, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  final AppPalette palette;
  final IconData centerIcon;
  final String? toggleLabel;

  const _PhoneFrame({
    required this.palette,
    required this.centerIcon,
    this.toggleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 190,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.textPrimary.withOpacity(0.85), width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(centerIcon, size: 46, color: palette.gold),
          if (toggleLabel != null) ...[
            const SizedBox(height: 18),
            _ToggleOffPill(palette: palette, label: toggleLabel!),
          ],
        ],
      ),
    );
  }
}

class _ToggleOffPill extends StatelessWidget {
  final AppPalette palette;
  final String label;

  const _ToggleOffPill({required this.palette, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.textSecondary.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StandaloneCheck extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;

  const _StandaloneCheck({required this.palette, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.gold,
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 48),
    );
  }
}
