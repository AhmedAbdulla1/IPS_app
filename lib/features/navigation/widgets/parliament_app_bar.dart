import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
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
  Size get preferredSize => const Size.fromHeight(200
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: onMenuTap,
                child: Icon(Icons.menu, color: palette.textPrimary, size: 35,),
              ),
            ),
            _ParliamentLogo(palette: palette),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: GestureDetector(
                onTap: onLanguageToggle,
                child: Text(
                  isArabic ? 'ع | En' : 'En | ع',
                  style: AppTextStyles.langToggle.copyWith(
                    color: palette.brownDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ParliamentLogo extends StatelessWidget {
  final AppPalette palette;

  const _ParliamentLogo({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/icon.png',
      height: 160,
      width: 160,
      fit: BoxFit.contain,
    );
  }
}
