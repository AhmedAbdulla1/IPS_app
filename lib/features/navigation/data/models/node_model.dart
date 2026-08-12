import '../../domain/entities/nav_node.dart';

/// تمثيل صف جدول `nodes` في سوبابيز — طبقة الـ Data، مسؤولة عن التحويل
/// من/لـ JSON بس، مش بتحمل أي منطق عمل.
class NodeModel {
  final int nodeId;
  final String levelId;
  final String nameAr;
  final String? nameEn;
  final String type; // 'poi' | 'intersection'

  /// نوع المرفق الثابت (facility_type) لو العقدة دي حمام/أسانسير/مخرج/
  /// كافيتيريا... إلخ — null لو عقدة عادية. راجع توثيق [NavNode.facilityType].
  final String? facilityType;

  final String? esp32Uuid;
  final double? x;
  final double? y;

  const NodeModel({
    required this.nodeId,
    required this.levelId,
    required this.nameAr,
    this.nameEn,
    required this.type,
    this.facilityType,
    this.esp32Uuid,
    this.x,
    this.y,
  });

  factory NodeModel.fromMap(Map<String, dynamic> map) {
    return NodeModel(
      nodeId: map['node_id'] as int,
      levelId: map['level_id'] as String,
      nameAr: map['name_ar'] as String,
      nameEn: map['name_en'] as String?,
      type: map['type'] as String,
      facilityType: map['facility_type'] as String?,
      esp32Uuid: map['esp32_uuid'] as String?,
      x: (map['x'] as num?)?.toDouble(),
      y: (map['y'] as num?)?.toDouble(),
    );
  }

  NavNode toEntity() {
    return NavNode(
      id: nodeId,
      levelId: levelId,
      nameAr: nameAr,
      nameEn: nameEn,
      type: type == 'intersection' ? NavNodeType.intersection : NavNodeType.poi,
      facilityType: facilityType,
      esp32Uuid: esp32Uuid,
      x: x,
      y: y,
    );
  }
}
