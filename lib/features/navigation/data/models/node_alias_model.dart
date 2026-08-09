import '../../domain/entities/node_alias.dart';

class NodeAliasModel {
  final int nodeId;
  final String aliasText;
  final String lang;

  const NodeAliasModel({
    required this.nodeId,
    required this.aliasText,
    required this.lang,
  });

  factory NodeAliasModel.fromMap(Map<String, dynamic> map) {
    return NodeAliasModel(
      nodeId: map['node_id'] as int,
      aliasText: map['alias_text'] as String,
      lang: map['lang'] as String,
    );
  }

  NodeAlias toEntity() {
    return NodeAlias(nodeId: nodeId, text: aliasText, lang: lang);
  }
}
