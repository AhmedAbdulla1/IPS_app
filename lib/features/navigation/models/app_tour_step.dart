import 'package:flutter/material.dart';

/// نموذج يمثل خطوة واحدة في الجولة التعريفية للتطبيق
class AppTourStep {
  final String id;
  final GlobalKey key;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final double borderRadius;
  final EdgeInsets padding;

  const AppTourStep({
    required this.id,
    required this.key,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(8.0),
  });
}
