import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';

/// صف عام لعنصر إعداد: أيقونة + عنوان (+ عنوان فرعي اختياري) + عنصر تريلينج
/// بيستقبل AppPalette عشان يستجيب للوضع الليلي.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AppPalette palette;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.palette,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // أيقونة داخل دائرة ذهبية فاتحة
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.goldLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: palette.brownDark, size: 22),
              ),
              const SizedBox(width: 14),
              // العنوان والعنوان الفرعي
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
