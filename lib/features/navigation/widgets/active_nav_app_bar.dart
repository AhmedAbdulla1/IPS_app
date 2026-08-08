import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';

/// شريط علوي مضغوط لشاشة التوجيه النشط — بيستجيب لمفتاح الوضع الليلي.
class ActiveNavAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onLanguageToggle;
  final AppPalette palette;

  const ActiveNavAppBar({
    super.key,
    this.onMenuTap,
    this.onLanguageToggle,
    this.palette = AppPalette.dark,
  });

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onMenuTap,
                  child: Icon(Icons.menu, color: palette.textPrimary, size: 24),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onLanguageToggle,
                  child: Icon(Icons.language_rounded, color: palette.gold, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Icon(Icons.account_balance_outlined, color: palette.gold, size: 28),
            const SizedBox(height: 4),
            Text(
              'مجلس النواب المصري'.tr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
