/// نوع النقطة: نقطة اهتمام (مكتب/قاعة/خدمة) أو مجرد تقاطع في المسار
enum NavNodeType { poi, intersection }

/// نقطة (node) في خريطة المبنى — كيان Domain نقي بدون أي اعتماد على Supabase أو Flutter.
class NavNode {
  final int id;
  final String levelId;
  final String nameAr;
  final String? nameEn;
  final NavNodeType type;

  /// نوع المرفق الثابت لو العقدة دي نقطة مرفق (زي 'elevator'، 'exit'،
  /// 'cafeteria'، 'restroom_male'، 'restroom_female') — null لو عقدة عادية.
  ///
  /// ده نظام منفصل تمامًا عن [Destination] القابل للبحث: المرافق دي
  /// أماكن معروفة وثابتة في أي مبنى (مفيش داعي تتسجل كـ "وجهة" يدور
  /// عليها المستخدم بالاسم)، فبتتحدد مباشرة على العقدة نفسها بدل ما
  /// تحتاج صف في جدول destinations. راجع
  /// NavigationScreenController._resolveNearestReachableDestination.
  final String? facilityType;

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
    this.facilityType,
    this.esp32Uuid,
    this.x,
    this.y,
  });

  @override
  String toString() => 'NavNode($id, $nameAr, level=$levelId)';
}
