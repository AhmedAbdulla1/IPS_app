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
    return ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(palette.gold),
        minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),

        )

        ),
      ),
      onPressed: onPressed,
      child: Text(
        'إلغاء'.tr,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: palette.textOnDark,
        ),
      ),
    );
  }
}
