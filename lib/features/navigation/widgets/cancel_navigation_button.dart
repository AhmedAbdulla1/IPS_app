import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';

/// زرار إلغاء الملاحة — بيرجع المستخدم لحالة "الموقع الحالي" الابتدائية.
class CancelNavigationButton extends StatelessWidget {
  final VoidCallback onPressed;
  final AppPalette palette;

  const CancelNavigationButton({
    super.key,
    required this.onPressed,
    this.palette = AppPalette.dark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: palette.gold,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'إلغاء الملاحة'.tr,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.textOnDark,
              ),
            ),
            Positioned(
              left: 8,
              child: Icon(Icons.cancel_outlined, color: palette.textOnDark, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
