import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parliament_ips/core/theme/app_colors.dart';
import 'package:parliament_ips/features/onboarding/onboarding_page.dart';
import 'package:parliament_ips/core/constants/app_assets.dart';
import 'package:parliament_ips/core/localization/locale_controller.dart';
import 'package:parliament_ips/core/theme/theme_controller.dart';

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  late PageController pageController;
  late LocaleController localeController;
  late ThemeController themeController;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    localeController = Get.find<LocaleController>();
    themeController = Get.find<ThemeController>();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SizeConfig().init(context);
    final bool isArabic = localeController.isArabic;
    final bool isDark = themeController.isDarkMode.value;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDark ? AppAssets.backgroundDark : AppAssets.backgroundLight,
            ),
            fit: BoxFit.cover,
          ),
        ),
        child:
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 80),
            Image.asset(AppAssets.appIcon, height: 100),
            const SizedBox(height: 80),
            TypewriterRichText(
              speed: const Duration(milliseconds: 100),
              spans: [
                TypewriterSpan(
                  text: "مرحباً بك في\n مجلس النواب المصري\n",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textOnDark
                        : AppColors.brownDark,
                  ),
                ),
                TypewriterSpan(
                  text: "مساعدك داخل المبنى",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                    color: isDark
                        ? Colors.grey[200]
                        : Colors.grey[700],
                  ),
                ),
              ],
            ),
            // RichText(
            //   textAlign: TextAlign.center,
            //   text: TextSpan(
            //     style: TextStyle(
            //       fontSize: 28,
            //       color: isDark? AppColors.textOnDark: AppColors.brownDark,
            //     ),
            //     children: [
            //       TextSpan(
            //         text: "مرحباً بك في\n مجلس النواب المصري\n",
            //         style: TextStyle(
            //           fontWeight: FontWeight.bold,
            //         ),
            //       ),
            //       TextSpan(
            //         text: "مساعدك داخل المبنى",
            //         style: TextStyle(
            //           fontSize: 18,
            //           fontWeight: FontWeight.normal,
            //           color: isDark
            //               ? Colors.grey[200]
            //               : Colors.grey[700]
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            const SizedBox(height: 80),
            TypewriterRichText(
              speed: const Duration(milliseconds: 100),
              delay: const Duration(milliseconds: 250),
              spans: [
                TypewriterSpan(
                  text: "Welcome to the\nEgyptian Parliament\n",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textOnDark
                        : AppColors.brownDark,
                  ),
                ),
                TypewriterSpan(
                  text: "Your indoor assistant",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                    color: isDark
                        ? Colors.grey[200]
                        : Colors.grey[700],
                  ),
                ),
              ],
            ),
            // RichText(
            //   textAlign: TextAlign.center,
            //
            //   text: TextSpan(
            //     style: TextStyle(
            //       fontSize: 28,
            //       color: isDark?AppColors.textOnDark:  AppColors.brownDark,
            //     ),
            //     children: [
            //       TextSpan(
            //         text: "Welcome to the \n Egyptian Parliament\n",
            //         style: TextStyle(
            //           fontWeight: FontWeight.bold,
            //
            //         ),
            //       ),
            //       TextSpan(
            //         text: "Your indoor assistant",
            //         style: TextStyle(
            //             fontSize: 18,
            //             fontWeight: FontWeight.normal,
            //             color:  isDark
            //                 ? Colors.grey[200]
            //                 : Colors.grey[700]
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: _buildButton(isArabic),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(bool isArabic) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Get.isDarkMode?AppColors.gold:  AppColors.brownDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => OnboardingPage()),
          );
        },
        child: Text('ابدأ\n Get Started',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
class TypewriterRichText extends StatefulWidget {
  final List<TypewriterSpan> spans;
  final TextAlign textAlign;
  final Duration speed;
  final Duration delay;

  const TypewriterRichText({
    super.key,
    required this.spans,
    this.textAlign = TextAlign.center,
    this.speed = const Duration(milliseconds: 60),
    this.delay = Duration.zero,
  });

  @override
  State<TypewriterRichText> createState() => _TypewriterRichTextState();
}

class _TypewriterRichTextState extends State<TypewriterRichText> {
  String _visibleText = '';

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  Future<void> _startTyping() async {
    if (widget.delay > Duration.zero) {
      await Future.delayed(widget.delay);
    }

    for (final span in widget.spans) {
      for (final char in span.text.characters) {
        if (!mounted) return;

        setState(() {
          _visibleText += char;
        });

        await Future.delayed(widget.speed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int remaining = _visibleText.length;

    final spans = <TextSpan>[];

    for (final span in widget.spans) {
      if (remaining <= 0) break;

      final count = remaining.clamp(0, span.text.length);

      spans.add(
        TextSpan(
          text: span.text.substring(0, count),
          style: span.style,
        ),
      );

      remaining -= count;
    }

    return RichText(
      textAlign: widget.textAlign,
      text: TextSpan(children: spans),
    );
  }
}

class TypewriterSpan {
  final String text;
  final TextStyle style;

  const TypewriterSpan({
    required this.text,
    required this.style,
  });
}