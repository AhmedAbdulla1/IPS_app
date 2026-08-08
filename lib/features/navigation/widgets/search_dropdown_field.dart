import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../controllers/navigation_controller.dart';
import '../models/navigation_destination.dart';

/// شريط بحث/منيو (Combobox): كتابة = بحث ذكي، والضغط على الحقل من غير كتابة = تصفح القائمة كاملة.
/// النتائج بتظهر Inline تحت الحقل مباشرة عشان تفضل واضحة للمستخدم.
class SearchDropdownField extends StatelessWidget {
  final NavigationScreenController controller;
  final AppPalette palette;

  const SearchDropdownField({
    super.key,
    required this.controller,
    this.palette = AppPalette.light,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(),
        Obx(() => _buildResultsPanel()),
      ],
    );
  }

  Widget _buildField() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: palette.shadow, blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.searchTextController,
              focusNode: controller.searchFocusNode,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              onChanged: controller.onSearchChanged,
              style: AppTextStyles.searchHint.copyWith(color: palette.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'ابحث عن مكتب أو قاعة...'.tr,
                hintStyle: AppTextStyles.searchHint.copyWith(color: palette.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.searchTextController,
            builder: (context, value, _) {
              final hasText = value.text.isNotEmpty;
              return GestureDetector(
                onTap: hasText ? controller.clearSelection : controller.openDropdown,
                child: Icon(
                  hasText ? Icons.close_rounded : Icons.expand_more_rounded,
                  color: palette.textSecondary,
                  size: 22,
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Icon(Icons.search, color: palette.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _buildResultsPanel() {
    if (!controller.isDropdownOpen.value) return const SizedBox.shrink();

    final results = controller.searchResults;
    final isBrowseMode = controller.searchTextController.text.trim().isEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: palette.shadow, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'مفيش نتائج مطابقة'.tr,
                  style: AppTextStyles.searchHint.copyWith(color: palette.textSecondary),
                ),
              ),
            )
          : isBrowseMode
              ? _buildGroupedList(results)
              : _buildFlatList(results),
    );
  }

  /// وضع المنيو (بدون كتابة): تقسيم حسب التصنيف لسهولة التصفح
  Widget _buildGroupedList(List<BuildingDestination> results) {
    final grouped = <DestinationCategory, List<BuildingDestination>>{};
    for (final item in results) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: grouped.entries.expand((entry) {
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                entry.key.arabicLabel.tr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
          ...entry.value.map((item) => _ResultRow(
                item: item,
                palette: palette,
                onTap: () => controller.selectDestination(item),
              )),
        ];
      }).toList(),
    );
  }

  /// وضع البحث (فيه كتابة): قائمة مسطحة مرتبة حسب قوة التطابق
  Widget _buildFlatList(List<BuildingDestination> results) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return _ResultRow(
          item: item,
          palette: palette,
          onTap: () => controller.selectDestination(item),
        );
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  final BuildingDestination item;
  final AppPalette palette;
  final VoidCallback onTap;

  const _ResultRow({required this.item, required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: palette.goldDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name.tr,
                textAlign: TextAlign.right,
                style: AppTextStyles.facilityLabel
                    .copyWith(fontSize: 13, color: palette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
