import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/node_model.dart';
import '../models/level_model.dart';
import '../models/node_alias_model.dart';
import '../models/edge_model.dart';
import '../models/vertical_connector_model.dart';

/// طبقة الوصول الخام لسوبابيز — بترجع Models بس، من غير أي منطق بناء graph
/// (ده شغل الـ repository).
class SupabaseNavigationDataSource {
  final SupabaseClient _client;

  SupabaseNavigationDataSource(this._client);

  Future<List<LevelModel>> fetchLevels() async {
    final rows = await _client.from('levels').select();
    return (rows as List)
        .map((row) => LevelModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<NodeModel>> fetchNodes() async {
    final rows = await _client.from('nodes').select();
    return (rows as List)
        .map((row) => NodeModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<NodeAliasModel>> fetchNodeAliases() async {
    final rows = await _client.from('node_aliases').select();
    return (rows as List)
        .map((row) => NodeAliasModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<EdgeModel>> fetchEdges() async {
    final rows = await _client.from('edges').select();
    return (rows as List)
        .map((row) => EdgeModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<VerticalConnectorModel>> fetchVerticalConnectors() async {
    final rows = await _client.from('vertical_connectors').select();
    return (rows as List)
        .map((row) => VerticalConnectorModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ConnectorStopModel>> fetchConnectorStops() async {
    final rows = await _client.from('connector_stops').select();
    return (rows as List)
        .map((row) => ConnectorStopModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
