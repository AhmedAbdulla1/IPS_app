/// نوع النقطة: نقطة اهتمام (مكتب/قاعة/خدمة) أو مجرد تقاطع في المسار
enum NavNodeType { poi, intersection }

/// نقطة (node) في خريطة المبنى — كيان Domain نقي بدون أي اعتماد على Supabase أو Flutter.
class NavNode {
  final int id;
  final String levelId;
  final String nameAr;
  final String? nameEn;
  final NavNodeType type;

  /// UUID البيكون المربوط بالنقطة دي — nullable لو لسه مفيش بيكون فعلي.
  final String? esp32Uuid;

  final double? x;
  final double? y;

  const NavNode({
    required this.id,
    required this.levelId,
    required this.nameAr,
    this.nameEn,
    required this.type,
    this.esp32Uuid,
    this.x,
    this.y,
  });

  @override
  String toString() => 'NavNode($id, $nameAr, level=$levelId)';
}
