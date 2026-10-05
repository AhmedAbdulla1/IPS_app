import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_palette.dart';
import '../../controllers/app_tour_controller.dart';
import '../../models/app_tour_step.dart';

/// ويدجت تراكبي مخصص لعرض الجولة التعريفية (App Tour)
///
/// يدعم الشاشة الرئيسية وشاشة الملاحة النشطة، مع حساب دقيق للإحداثيات
/// بالاعتماد على RenderBox الخاص بالـ Overlay نفسه لتفادي أي إزاحة للشاشة.
class AppTourOverlay extends StatefulWidget {
  final AppTourController controller;
  final AppPalette palette;
  final bool isArabic;

  const AppTourOverlay({
    super.key,
    required this.controller,
    required this.palette,
    required this.isArabic,
  });

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _overlayKey = GlobalKey();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final step = widget.controller.currentStepData;
      if (step == null || !widget.controller.isTourActive.value) {
        return const SizedBox.shrink();
      }

      return Positioned.fill(
        child: Container(
          key: _overlayKey,
          color: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final RenderBox? overlayBox =
                  _overlayKey.currentContext?.findRenderObject() as RenderBox?;

              // في حال لم يكتمل أول إطار لبناء الـ overlayBox
              if (overlayBox == null || !overlayBox.hasSize) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {});
                });
                return const SizedBox.shrink();
              }

              final targetRect = widget.controller.getTargetRect(
                step.key,
                padding: step.padding,
                ancestor: overlayBox,
              );

              // فحص أمان صارم: لو العنصر غير مرئي تماماً في الشاشة
              if (targetRect == null) {
                return const SizedBox.shrink();
              }

              final overlaySize =
                  Size(constraints.maxWidth, constraints.maxHeight);
              final bool placeBelow =
                  targetRect.bottom + 215 <= overlaySize.height;

              return Directionality(
                textDirection:
                    widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
                child: Stack(
                  children: [
                    // 1) الخلفية المعتمة مع قص الـ Spotlight والنبض الذهبي
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          size: overlaySize,
                          painter: _SpotlightPainter(
                            targetRect: targetRect,
                            borderRadius: step.borderRadius,
                            pulseValue: _pulseAnimation.value,
                            glowColor: widget.palette.gold,
                          ),
                        );
                      },
                    ),

                    // 2) بطاقة التوجيه والتحكم (Tooltip Card)
                    _buildTooltipCard(
                      context: context,
                      step: step,
                      targetRect: targetRect,
                      placeBelow: placeBelow,
                      overlaySize: overlaySize,
                      overlayBox: overlayBox,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Widget _buildTooltipCard({
    required BuildContext context,
    required AppTourStep step,
    required Rect targetRect,
    required bool placeBelow,
    required Size overlaySize,
    required RenderBox overlayBox,
  }) {
    final stepIndex = widget.controller.currentStep.value;
    final totalSteps = widget.controller.currentSteps.length;
    final isLastStep = stepIndex == totalSteps - 1;

    // حساب الموضع الرأسي للبطاقة بنظام محلي منضبط 100%
    final double? top = placeBelow ? (targetRect.bottom + 12) : null;
    final double? bottom =
        !placeBelow ? (overlaySize.height - targetRect.top + 12) : null;

    return Positioned(
      top: top,
      bottom: bottom,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.palette.gold.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الهيدر: شارة الخطوة وزر الإغلاق السريع
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.palette.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.palette.gold.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.isArabic
                          ? 'خطوة ${stepIndex + 1} من $totalSteps'
                          : 'Step ${stepIndex + 1} of $totalSteps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.palette.gold,
                        fontFamily: 'Mulish',
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.controller.skipTour,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: widget.palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // العنوان
              Text(
                widget.isArabic ? step.titleAr : step.titleEn,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: widget.palette.textPrimary,
                  fontFamily: 'Mulish',
                ),
              ),
              const SizedBox(height: 6),

              // الشرح
              Text(
                widget.isArabic ? step.descriptionAr : step.descriptionEn,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: widget.palette.textSecondary,
                  fontFamily: 'Mulish',
                ),
              ),
              const SizedBox(height: 16),

              // أزرار التحكم السفلية
              Row(
                children: [
                  // زر التخطي
                  TextButton(
                    onPressed: widget.controller.skipTour,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      'تخطي'.tr,
                      style: TextStyle(
                        color: widget.palette.textSecondary,
                        fontSize: 14,
                        fontFamily: 'Mulish',
                      ),
                    ),
                  ),
                  const Spacer(),

                  // زر السابق (يظهر بعد الخطوة الأولى)
                  if (stepIndex > 0) ...[
                    OutlinedButton(
                      onPressed: () =>
                          widget.controller.previousStep(ancestor: overlayBox),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: widget.palette.gold.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'السابق'.tr,
                        style: TextStyle(
                          color: widget.palette.textPrimary,
                          fontSize: 13,
                          fontFamily: 'Mulish',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // زر التالي أو إنهاء
                  ElevatedButton(
                    onPressed: isLastStep
                        ? widget.controller.completeTour
                        : () => widget.controller.nextStep(ancestor: overlayBox),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.palette.gold,
                      foregroundColor: widget.palette.textOnDark,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isLastStep ? 'فهمت ذلك'.tr : 'التالي'.tr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Mulish',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter لقص مساحة العنصر المستهدف ورسم النبض الذهبي حوله
class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double borderRadius;
  final double pulseValue;
  final Color glowColor;

  _SpotlightPainter({
    required this.targetRect,
    required this.borderRadius,
    required this.pulseValue,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final spotlightRRect = RRect.fromRectAndRadius(
      targetRect,
      Radius.circular(borderRadius),
    );

    final spotlightPath = Path()..addRRect(spotlightRRect);

    // قص مستطيل الهدف من الخلفية الداكنة
    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      spotlightPath,
    );

    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.74)
      ..style = PaintingStyle.fill;

    canvas.drawPath(combinedPath, backgroundPaint);

    // رسم هالة النبض الذهبية (Pulsing Glow Halo) حول مستطيل الهدف
    final glowInflate = 2.0 + (4.0 * pulseValue);
    final glowRRect = RRect.fromRectAndRadius(
      targetRect.inflate(glowInflate),
      Radius.circular(borderRadius + 2.0),
    );

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.35 + (0.55 * (1.0 - pulseValue)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawRRect(glowRRect, glowPaint);

    // حلقة داخلية ثابتة رقيقة للحدة البصرية
    final innerStrokePaint = Paint()
      ..color = glowColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(spotlightRRect, innerStrokePaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.glowColor != glowColor;
  }
}
