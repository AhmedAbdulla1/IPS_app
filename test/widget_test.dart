import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parliament_ips/features/navigation/utils/arabic_search_utils.dart';
import 'package:parliament_ips/core/theme/app_colors.dart';
import 'package:parliament_ips/core/theme/app_palette.dart';

void main() {
  group('ArabicSearchUtils Tests', () {
    test('normalizes Arabic alef variants correctly', () {
      expect(ArabicSearchUtils.normalize('إسلام'), 'اسلام');
      expect(ArabicSearchUtils.normalize('أحمد'), 'احمد');
      expect(ArabicSearchUtils.normalize('آمال'), 'امال');
    });

    test('normalizes teh marbuta and alef maqsura', () {
      expect(ArabicSearchUtils.normalize('مجلس الأمة'), 'مجلس الامه');
      expect(ArabicSearchUtils.normalize('مبنى'), 'مبني');
    });
  });

  group('UI & Theme Smoke Tests', () {
    testWidgets('App palette and basic widgets render properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('مجلس النواب'),
              backgroundColor: AppColors.gold,
            ),
            body: Center(
              child: Text(
                'مرحباً بك',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      );

      expect(find.text('مجلس النواب'), findsOneWidget);
      expect(find.text('مرحباً بك'), findsOneWidget);
    });

    test('AppPalette instantiates correctly', () {
      final light = AppPalette.light;
      final dark = AppPalette.dark;
      expect(light.gold, AppColors.gold);
      expect(dark.background, AppColorsDark.background);
    });
  });
}
