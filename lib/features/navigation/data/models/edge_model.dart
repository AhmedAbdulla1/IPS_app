/// تمثيل صف جدول `edges` — الحافة في الداتا بيز غير موجّهة (undirected)،
/// التحويل لحافتين موجّهتين (A→B, B→A) بيحصل في الـ repository وقت بناء
/// الـ graph مش هنا.
class EdgeModel {
  final int nodeIdA;
  final int nodeIdB;
  final double? distanceMeters;

  /// قيمة تقريبية مؤقتة تُستخدم لو `distance_meters` لسه null (زي ما
  /// موضّح في ملاحظة رقم 7 في `map_data_template.json` — لحد ما تتحط
  /// قياسات حقيقية).
  static const double defaultDistanceMeters = 5.0;

  const EdgeModel({
    required this.nodeIdA,
    required this.nodeIdB,
    this.distanceMeters,
  });

  factory EdgeModel.fromMap(Map<String, dynamic> map) {
    return EdgeModel(
      nodeIdA: map['node_id_a'] as int,
      nodeIdB: map['node_id_b'] as int,
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
    );
  }

  double get effectiveDistance => distanceMeters ?? defaultDistanceMeters;
}
