/// تمثيل صف جدول `destinations`
class DestinationModel {
  final int destinationId;
  final String nameAr;
  final String? nameEn;
  final String? shortcutType;

  const DestinationModel({
    required this.destinationId,
    required this.nameAr,
    this.nameEn,
    this.shortcutType,
  });

  factory DestinationModel.fromMap(Map<String, dynamic> map) {
    return DestinationModel(
      destinationId: map['destination_id'] as int,
      nameAr: map['name_ar'] as String,
      nameEn: map['name_en'] as String?,
      shortcutType: map['shortcut_type'] as String?,
    );
  }
}

/// تمثيل صف جدول `destination_nodes`
class DestinationNodeModel {
  final int destinationId;
  final int nodeId;

  const DestinationNodeModel({required this.destinationId, required this.nodeId});

  factory DestinationNodeModel.fromMap(Map<String, dynamic> map) {
    return DestinationNodeModel(
      destinationId: map['destination_id'] as int,
      nodeId: map['node_id'] as int,
    );
  }
}

/// تمثيل صف جدول `destination_aliases`
class DestinationAliasModel {
  final int destinationId;
  final String aliasText;
  final String lang;

  const DestinationAliasModel({
    required this.destinationId,
    required this.aliasText,
    required this.lang,
  });

  factory DestinationAliasModel.fromMap(Map<String, dynamic> map) {
    return DestinationAliasModel(
      destinationId: map['destination_id'] as int,
      aliasText: map['alias_text'] as String,
      lang: map['lang'] as String,
    );
  }
}
