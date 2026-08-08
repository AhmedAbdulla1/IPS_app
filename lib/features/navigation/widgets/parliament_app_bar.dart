import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';

/// شريط علوي مخصص: زرار قائمة، شعار المجلس، وتبديل اللغة.
class ParliamentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onLanguageToggle;
  final bool isArabic;
  final AppPalette palette;

  const ParliamentAppBar({
    super.key,
    this.onMenuTap,
    this.onLanguageToggle,
    this.isArabic = true,
    this.palette = AppPalette.light,
  });

  @override
  Size get preferredSize => const Size.fromHeight(100);

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
                  child: Icon(Icons.menu, color: palette.textPrimary, size: 26),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onLanguageToggle,
                  child: Text(
                    isArabic ? 'ع | En' : 'En | ع',
                    style: AppTextStyles.langToggle.copyWith(color: palette.brownDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _ParliamentLogo(palette: palette),
          ],
        ),
      ),
    );
  }
}

/// شعار مجلس النواب — placeholder مؤقت (أيقونة + نص)
/// استبدله بصورة الشعار الفعلية عند توفرها:
/// Image.asset('assets/images/parliament_logo.png')
class _ParliamentLogo extends StatelessWidget {
  final AppPalette palette;

  const _ParliamentLogo({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.goldLight, palette.gold],
            ),
            boxShadow: [
              BoxShadow(color: palette.shadow, blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(Icons.account_balance_rounded, color: palette.brownDark, size: 26),
        ),
        const SizedBox(height: 6),
        Text(
          'مجلس النواب المصري'.tr,
          style: AppTextStyles.logoTitleAr.copyWith(color: palette.brownDark),
        ),
        const SizedBox(height: 2),
        Text(
          'EGYPTIAN PARLIAMENT',
          style: AppTextStyles.logoSubtitleEn.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}
