/// تمثيل صف جدول `vertical_connectors` (أسانسير/سلم)
class VerticalConnectorModel {
  final int connectorId;
  final String nameAr;
  final String? nameEn;
  final String connectorType; // 'elevator' | 'stairs'

  const VerticalConnectorModel({
    required this.connectorId,
    required this.nameAr,
    this.nameEn,
    required this.connectorType,
  });

  factory VerticalConnectorModel.fromMap(Map<String, dynamic> map) {
    return VerticalConnectorModel(
      connectorId: map['connector_id'] as int,
      nameAr: map['name_ar'] as String,
      nameEn: map['name_en'] as String?,
      connectorType: map['connector_type'] as String,
    );
  }
}

/// تمثيل صف جدول `connector_stops` — عند أي نود في أي دور بيوقف الموصل ده.
class ConnectorStopModel {
  final int connectorId;
  final String levelId;
  final int nodeId;

  const ConnectorStopModel({
    required this.connectorId,
    required this.levelId,
    required this.nodeId,
  });

  factory ConnectorStopModel.fromMap(Map<String, dynamic> map) {
    return ConnectorStopModel(
      connectorId: map['connector_id'] as int,
      levelId: map['level_id'] as String,
      nodeId: map['node_id'] as int,
    );
  }
}
