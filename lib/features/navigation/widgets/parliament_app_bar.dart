import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
class ParliamentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onLanguageToggle;
  final VoidCallback? onTourTap;
  final Key? tourKey;
  final bool isArabic;
  final AppPalette palette;

  const ParliamentAppBar({
    super.key,
    this.onMenuTap,
    this.onLanguageToggle,
    this.onTourTap,
    this.tourKey,
    this.isArabic = true,
    this.palette = AppPalette.light,
  });

  @override
  Size get preferredSize => const Size.fromHeight(200);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          key: tourKey,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // 1. الشعار في المنتصف بدقة تامة
              _ParliamentLogo(palette: palette),

              // 2. زر القائمة على البداية
              Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GestureDetector(
                    onTap: onMenuTap,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(Icons.menu, color: palette.textPrimary, size: 35),
                  ),
                ),
              ),

              // 3. أزرار الإرشاد واللغة على النهاية
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (onTourTap != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 4.0),
                        child: Tooltip(
                          message: isArabic ? 'دليل الإرشاد' : 'Tour Guide',
                          child: GestureDetector(
                            onTap: onTourTap,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: palette.gold.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: palette.goldDark,
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.shadow.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.explore_outlined,
                                    color: palette.brownDark,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isArabic ? 'إرشاد' : 'Guide',
                                    style: TextStyle(
                                      color: palette.brownDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Mulish',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: GestureDetector(
                        onTap: onLanguageToggle,
                        behavior: HitTestBehavior.opaque,
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
            ],
          ),
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
