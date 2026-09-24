import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parliament_ips/core/localization/locale_controller.dart';
import 'package:parliament_ips/features/navigation/models/navigation_destination.dart';
import '../../../core/theme/app_palette.dart';

/// عنوان الوجهة الحالية أثناء التوجيه: "إلى: <اسم المكان>" + الدور الحالي
class DestinationHeader extends StatelessWidget {
  final BuildingDestination? destination;
  final String floorLabel;
  final AppPalette palette;

  const DestinationHeader({
    super.key,
    required this.destination,
    required this.floorLabel,
    this.palette = AppPalette.dark,
  });

  @override
  Widget build(BuildContext context) {
    bool isArabic = Get.find<LocaleController>().isArabic;
    return Column(
      children: [
        Text(
          '${'إلى'.tr}: ${isArabic? destination?.nameAr??"": destination?.nameEn??""}  ',
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
