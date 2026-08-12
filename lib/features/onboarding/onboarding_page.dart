import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pathfinder/core/theme/app_colors.dart';
import 'package:pathfinder/core/theme/app_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pathfinder/core/constants/app_assets.dart';
import 'package:pathfinder/core/localization/locale_controller.dart';
import 'package:pathfinder/core/theme/theme_controller.dart';
import 'package:pathfinder/features/navigation/views/main_navigation_screen.dart';
import 'package:pathfinder/utils/constants.dart';
import 'package:pathfinder/utils/size_config.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late PageController pageController;
  int currentPage = 0;
  late LocaleController localeController;
  late ThemeController themeController;

  final List<Map<String, dynamic>> onboardingPages = [
    {
      'image': AppAssets.onboarding1,
      'titleAr': 'اتبع اتجاه السهم',
      'titleEn': 'Follow the Direction',
      'descriptionAr': 'السهم يوجهك نحو اتجاه خطوتك التالية',
      'descriptionEn': 'The arrow points you toward your next turn.',
    },
    {
      'image': AppAssets.onboarding2,
      'titleAr': 'اجعل هاتفك جاهز',
      'titleEn': 'Keep Your Phone Ready',
      'descriptionAr':
          'أمسك هاتفك بشكل طبيعي وحافظ عليه ثابت أثناء اتباع السهم',
      'descriptionEn':
          'Hold your phone naturally and keep it steady while following the arrow.',
    },
    {
      'image': AppAssets.onboarding3,
      'titleAr': 'اضبط البوصلة',
      'titleEn': 'Calibrate Your Compass',
      'descriptionAr':
          'حرك هاتفك في شكل رقم 8 للحصول على قراءات دقيقة للاتجاهات',
      'descriptionEn':
          'Move your phone in a figure-eight motion for accurate direction readings.',
    },
  ];

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

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('initial', true);
    print('[ONBOARDING] ✓ Saved: initial = true');
    if (mounted) {
      Get.offAll(() => const MainNavigationScreen());
    }
  }

  void _nextPage() {
    if (currentPage < onboardingPages.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    pageController.jumpToPage(onboardingPages.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final bool isArabic = localeController.isArabic;
    final bool isDark = themeController.isDarkMode.value;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDark
                  ? AppAssets.backgroundDark
                  : AppAssets.backgroundLight,
            ),
            fit: BoxFit.cover,
          ),
        ),

        child: SafeArea(
          child: Column(
            children: [

              // =========================
              // TOP CONTROLS
              // =========================

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [

                    // THEME
                    GestureDetector(
                      onTap: () {
                        themeController.toggleDarkMode();
                      },

                      child: Container(
                        padding: const EdgeInsets.all(8),

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : Colors.white.withOpacity(0.55),
                        ),

                        child: Icon(
                          isDark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,

                          size: 25,

                          color: isDark
                              ? Colors.white
                              : AppColors.brownDark,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // LANGUAGE
                    GestureDetector(
                      onTap: () {
                        localeController.toggleLocale();
                      },

                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),

                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : Colors.white.withOpacity(0.55),

                          border: Border.all(
                            color: isDark
                                ? Colors.white30
                                : AppColors.brownDark,
                            width: 1.2,
                          ),
                        ),

                        child: Text(
                          isArabic ? 'EN' : 'ع',

                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.brownDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // =========================
              // MOVING CONTENT
              // =========================

              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  itemCount: onboardingPages.length,

                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },

                  itemBuilder: (context, index) {
                    final page = onboardingPages[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),

                      child: Column(
                        children: [

                          const SizedBox(height: 20),

                          // TITLE
                          Text(
                            isArabic
                                ? page['titleAr'] as String
                                : page['titleEn'] as String,

                            textAlign: TextAlign.center,

                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textOnDark
                                  : AppColors.brownDark,
                            ),
                          ),

                          const SizedBox(height: 15),

                          // DESCRIPTION
                          Text(
                            isArabic
                                ? page['descriptionAr'] as String
                                : page['descriptionEn'] as String,

                            textAlign: TextAlign.center,

                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                          ),

                          const Spacer(),

                          // IMAGE
                          Image.asset(
                            page['image'] as String,
                            fit: BoxFit.contain,
                          ),

                          const Spacer(),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // =========================
              // FIXED BOTTOM CONTROLS
              // =========================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  15,
                ),

                child: Column(
                  children: [

                    _buildDots(isArabic),

                    const SizedBox(height: 20),

                    _buildButton(isArabic),

                    const SizedBox(height: 5),

                    currentPage==2? SizedBox(
                      height: 30,
                    ) :TextButton(
                      onPressed: _skipOnboarding,

                      child: Text(
                        isArabic ? 'تخطي' : 'Skip',

                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white
                              : AppColors.brownDark,
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
    );;
  }

  Widget _buildDots(bool isArabic) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        onboardingPages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: currentPage == index
                ? AppColors.brownDark
                : Colors.grey[400],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(bool isArabic) {
    final isLastPage = currentPage == onboardingPages.length - 1;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brownDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _nextPage,
        child: Text(
          isLastPage
              ? (isArabic ? 'ابدأ' : 'Get Started')
              : (isArabic ? 'التالي' : 'Next'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
