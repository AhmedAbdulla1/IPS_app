import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// حقل بحث عن مكتب أو قاعة
class FacilitySearchBar extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final String hintText;

  const FacilitySearchBar({
    super.key,
    this.onChanged,
    this.hintText = 'ابحث عن مكتب أو قاعة...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              onChanged: onChanged,
              style: AppTextStyles.searchHint.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: hintText,
                hintStyle: AppTextStyles.searchHint,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.search, color: AppColors.textSecondary, size: 22),
        ],
      ),
    );
  }
}
