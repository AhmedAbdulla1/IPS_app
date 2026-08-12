import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';

/// عنصر واحد في قايمة الأذونات المجمّعة (بلوتوث / موقع).
class PermissionChecklistItem {
  final IconData icon;
  final String title;
  final String statusLabel;
  final bool isGranted;
  final String actionLabel;
  final VoidCallback onAction;

  const PermissionChecklistItem({
    required this.icon,
    required this.title,
    required this.statusLabel,
    required this.isGranted,
    required this.actionLabel,
    required this.onAction,
  });
}

/// كارت "أذونات مطلوبة" — بيعرض قايمة الأذونات الناقصة كل واحد في صف
/// مستقل مع زرار الحل المناسب ليه، وفي الآخر زرار "حاول مرة أخرى" عام.
class PermissionChecklistCard extends StatelessWidget {
  final AppPalette palette;
  final String title;
  final String description;
  final List<PermissionChecklistItem> items;
  final VoidCallback onRetry;

  const PermissionChecklistCard({
    super.key,
    required this.palette,
    required this.title,
    required this.description,
    required this.items,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title.tr,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 1, color: palette.goldLight),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.diamond, size: 6, color: palette.gold),
            ),
            Container(width: 36, height: 1, color: palette.goldLight),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          description.tr,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.6,
            color: palette.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ChecklistRow(palette: palette, item: item),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.brownDark,
              side: BorderSide(color: palette.brownDark, width: 1.4),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'حاول مرة أخرى'.tr,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final AppPalette palette;
  final PermissionChecklistItem item;

  const _ChecklistRow({required this.palette, required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isGranted ? palette.statusGreen : palette.statusError;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.goldLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: palette.brownDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.tr,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.statusLabel.tr,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (!item.isGranted)
            ElevatedButton(
              onPressed: item.onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.brownDark,
                foregroundColor: palette.textOnDark,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                item.actionLabel.tr,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          else
            Icon(Icons.check_circle_rounded, color: palette.statusGreen, size: 22),
        ],
      ),
    );
  }
}
