import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/locale_controller.dart';
import '../controllers/navigation_controller.dart';
import '../models/navigation_destination.dart';

/// شريط بحث/منيو (Combobox): كتابة = بحث ذكي، والضغط على الحقل من غير كتابة = تصفح القائمة كاملة.
///
/// ملاحظة تصميم: النتائج بتتعرض عن طريق [OverlayEntry] طايف فوق باقي محتوى
/// الشاشة (مش Inline جوه الـ Column) — عشان لو القائمة طويلة (لحد 300px)
/// ميعملش overflow في الـ Column بتاع IdleHomeScreen. الـ Column الأصلي
/// عنده عناصر بأحجام ثابتة + Spacer، والـ Spacer بيقلل لحد صفر بس مش بيروح
/// بالسالب، فأي زيادة حقيقية في الارتفاع (زي فتح القائمة) هتعمل overflow
/// مهما كان الـ Spacer موجود — الحل الصحيح إن القائمة متتحطش في التخطيط
/// (layout) الأساسي أصلاً.
class SearchDropdownField extends StatefulWidget {
  final NavigationScreenController controller;
  final AppPalette palette;

  const SearchDropdownField({
    super.key,
    required this.controller,
    this.palette = AppPalette.light,
  });

  @override
  State<SearchDropdownField> createState() => _SearchDropdownFieldState();
}

class _SearchDropdownFieldState extends State<SearchDropdownField> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Worker? _worker;

  NavigationScreenController get controller => widget.controller;
  AppPalette get palette => widget.palette;

  @override
  void initState() {
    super.initState();
    _worker = ever(controller.isDropdownOpen, (isOpen) {
      if (isOpen) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
    if (controller.isDropdownOpen.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
    }
  }

  @override
  void dispose() {
    _worker?.dispose();
    _removeOverlay();
    super.dispose();
  }

  double get _fieldWidth {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize
        ? box.size.width
        : MediaQuery.of(context).size.width - 40;
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        width: _fieldWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56), // ارتفاع الحقل (48) + المسافة (8)
          child: Material(
            color: Colors.transparent,
            child: Obx(() => _buildResultsPanel()),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(key: _fieldKey, child: _buildField()),
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
            child: Obx(() {
              // اتجاه ومحاذاة الكتابة بيتبعوا لغة التطبيق الفعلية بدل ما يبقوا
              // مثبتين على RTL دايمًا — كانت دي سبب عدم تغيّر الاتجاه مع
              // الإنجليزي.
              final isArabic = Get.find<LocaleController>().isArabic;
              return TextField(
                controller: controller.searchTextController,
                focusNode: controller.searchFocusNode,
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                onChanged: controller.onSearchChanged,
                style: AppTextStyles.searchHint.copyWith(color: palette.textPrimary),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: 'ابحث عن مكتب أو قاعة...'.tr,
                  hintStyle: AppTextStyles.searchHint.copyWith(color: palette.textSecondary),
                ),
              );
            }),
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
