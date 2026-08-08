import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';

/// عنوان الوجهة الحالية أثناء التوجيه: "إلى: <اسم المكان>" + الدور الحالي
class DestinationHeader extends StatelessWidget {
  final String destinationName;
  final String floorLabel;
  final AppPalette palette;

  const DestinationHeader({
    super.key,
    required this.destinationName,
    required this.floorLabel,
    this.palette = AppPalette.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${'إلى'.tr}: ${destinationName.tr}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              floorLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.location_on_rounded, color: palette.gold, size: 14),
          ],
        ),
      ],
    );
  }
}
