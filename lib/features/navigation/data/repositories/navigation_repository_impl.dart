import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/building_graph.dart';
import '../../domain/entities/nav_edge.dart';
import '../../domain/entities/nav_node.dart';
import '../../domain/entities/nav_level.dart';
import '../../domain/entities/destination.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../datasources/supabase_navigation_datasource.dart';
import '../models/node_model.dart';
import '../models/level_model.dart';
import '../models/edge_model.dart';
import '../models/destination_model.dart';
import '../models/vertical_connector_model.dart'
    show ConnectorStopModel, VerticalConnectorModel;

/// التنفيذ الحقيقي لـ [NavigationRepository] — بيجيب الجداول الست من
/// سوبابيز عن طريق [SupabaseNavigationDataSource] وبيبني منها [BuildingGraph]
/// واحد موحّد، فيه حواف الاتصال الرأسي (أسانسير/سلم) كحواف عادية بين
/// الأدوار المختلفة (مش حالة خاصة زي الخوارزمية القديمة).
///
/// كاش دائم: [SupabaseNavigationDataSource] بيتكفّل بتخزين كل جدول محليًا
/// ويرجع له تلقائيًا لو الشبكة فشلت، فالميثود دي مش محتاجة تعرف تفاصيل
/// الكاش — بس بتصفّر فلاج [SupabaseNavigationDataSource.usedCacheInLastFetch]
/// قبل ما تبدأ، وبتنقله لـ [BuildingGraph.isFromCache] بعد ما تخلص، عشان
/// الطبقات الأعلى (Controller/UI) تعرف تنبّه المستخدم إنه شايف بيانات
/// مخزّنة بدل الأحدث.
class NavigationRepositoryImpl implements NavigationRepository {
  final SupabaseNavigationDataSource _dataSource;

  /// تكلفة تقريبية (بالمتر) لعبور أي اتصال رأسي (أسانسير/سلم) — قابلة
  /// للتعديل. مفيش قياس حقيقي لوقت الأسانسير حاليًا، فده رقم تقديري بسيط
  /// يخلي الـ A* يفضّل أقصر مسار عبره بدل ما يكون "مجاني" تمامًا (0).
  static const double _verticalTraversalCost = 3.0;

  BuildingGraph? _cachedGraph;

  NavigationRepositoryImpl(this._dataSource);

  @override
  BuildingGraph? get cachedGraph => _cachedGraph;

  @override
  Future<DateTime?> getLastSyncedAt() => _dataSource.getLastSyncedAt();

  @override
  Future<BuildingGraph?> loadCachedGraph() async {
    if (_cachedGraph != null) {
      return _cachedGraph;
    }

    // 1. محاولة قراءة كاش RPC أولاً (سريعة وشاملة)
    try {
      final rpcData = await _dataSource.readCachedRpcGraph();
      if (rpcData != null) {
        final graph = _buildGraphFromRpcData(rpcData);
        _cachedGraph = graph;
        return graph;
      }
    } catch (e) {
      AppLogger.debug('[NavigationRepository] Cached RPC read error: $e');
    }

    // 2. محاولة قراءة كاش الجداول الفردية
    try {
      final nodeModels = await _dataSource.readTableFromCacheOnly(
        table: 'nodes',
        fromMap: NodeModel.fromMap,
      );
      final levelModels = await _dataSource.readTableFromCacheOnly(
        table: 'levels',
        fromMap: LevelModel.fromMap,
      );
      final edgeModels = await _dataSource.readTableFromCacheOnly(
        table: 'edges',
        fromMap: EdgeModel.fromMap,
      );

      if (nodeModels != null && levelModels != null && edgeModels != null) {
        final connectorModels = await _dataSource.readTableFromCacheOnly(
          table: 'vertical_connectors',
          fromMap: VerticalConnectorModel.fromMap,
        ) ?? [];
        final connectorStopModels = await _dataSource.readTableFromCacheOnly(
          table: 'connector_stops',
          fromMap: ConnectorStopModel.fromMap,
        ) ?? [];
        final destinationModels = await _dataSource.readTableFromCacheOnly(
          table: 'destinations',
          fromMap: DestinationModel.fromMap,
        ) ?? [];
        final destinationNodeModels = await _dataSource.readTableFromCacheOnly(
          table: 'destination_nodes',
          fromMap: DestinationNodeModel.fromMap,
        ) ?? [];
        final destinationAliasModels = await _dataSource.readTableFromCacheOnly(
          table: 'destination_aliases',
          fromMap: DestinationAliasModel.fromMap,
        ) ?? [];

        final graph = _buildGraphFromModels(
          levelModels: levelModels,
          nodeModels: nodeModels,
          edgeModels: edgeModels,
          connectorModels: connectorModels,
          connectorStopModels: connectorStopModels,
          destinationModels: destinationModels,
          destinationNodeModels: destinationNodeModels,
          destinationAliasModels: destinationAliasModels,
          isFromCache: true,
        );
        _cachedGraph = graph;
        return graph;
      }
    } catch (e) {
      AppLogger.debug('[NavigationRepository] Cached tables read error: $e');
    }

    return null;
  }

  @override
  Future<BuildingGraph> loadGraph({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedGraph != null) {
      return _cachedGraph!;
    }

    _dataSource.resetCacheFlag();

    // المحاولة 1: استدعاء دالة RPC واحدة سريعة جداً للحصول على كامل الخريطة
    try {
      final rpcData = await _dataSource.fetchBuildingGraphRpc();
      if (rpcData != null) {
        final graph = _buildGraphFromRpcData(rpcData);
        _cachedGraph = graph;
        return graph;
      }
    } catch (e) {
      AppLogger.debug('[NavigationRepository] ⚠️ RPC failed, falling back to individual tables: $e');
    }

    // المحاولة 2 (Fallback): جلب الجداول بالتوازي بالطريقة القديمة
    final levelsFuture = _dataSource.fetchLevels();
    final nodesFuture = _dataSource.fetchNodes();
    final edgesFuture = _dataSource.fetchEdges();
    final connectorsFuture = _dataSource.fetchVerticalConnectors();
    final connectorStopsFuture = _dataSource.fetchConnectorStops();
    final destinationsFuture = _dataSource.fetchDestinations();
    final destinationNodesFuture = _dataSource.fetchDestinationNodes();
    final destinationAliasesFuture = _dataSource.fetchDestinationAliases();

    final levelModels = await levelsFuture;
    final nodeModels = await nodesFuture;
    final edgeModels = await edgesFuture;
    final connectorModels = await connectorsFuture;
    final connectorStopModels = await connectorStopsFuture;
    final destinationModels = await destinationsFuture;
    final destinationNodeModels = await destinationNodesFuture;
    final destinationAliasModels = await destinationAliasesFuture;

    final graph = _buildGraphFromModels(
      levelModels: levelModels,
      nodeModels: nodeModels,
      edgeModels: edgeModels,
      connectorModels: connectorModels,
      connectorStopModels: connectorStopModels,
      destinationModels: destinationModels,
      destinationNodeModels: destinationNodeModels,
      destinationAliasModels: destinationAliasModels,
      isFromCache: _dataSource.usedCacheInLastFetch,
    );

    _cachedGraph = graph;
    return graph;
  }

  BuildingGraph _buildGraphFromModels({
    required List<LevelModel> levelModels,
    required List<NodeModel> nodeModels,
    required List<EdgeModel> edgeModels,
    required List<VerticalConnectorModel> connectorModels,
    required List<ConnectorStopModel> connectorStopModels,
    required List<DestinationModel> destinationModels,
    required List<DestinationNodeModel> destinationNodeModels,
    required List<DestinationAliasModel> destinationAliasModels,
    required bool isFromCache,
  }) {

    // --- الأدوار والنقاط ---
    final levelsById = <String, NavLevel>{
      for (final m in levelModels) m.levelId: m.toEntity(),
    };
    final nodesById = <int, NavNode>{
      for (final m in nodeModels) m.nodeId: m.toEntity(),
    };

    // --- الحواف: كل حافة عادية بتتحط في الاتجاهين ---
    final adjacency = <int, List<NavEdge>>{};
    void addDirectedEdge(NavEdge edge) {
      adjacency.putIfAbsent(edge.fromNodeId, () => []).add(edge);
    }

    for (final edge in edgeModels) {
      final fromNode = nodesById[edge.nodeIdA];
      final toNode = nodesById[edge.nodeIdB];
      final fromOrder = fromNode != null ? (levelsById[fromNode.levelId]?.order ?? 0) : 0;
      final toOrder = toNode != null ? (levelsById[toNode.levelId]?.order ?? 0) : 0;

      NavEdgeKind kind = NavEdgeKind.walk;
      if (edge.kind == 'elevator') {
        kind = NavEdgeKind.elevator;
      } else if (edge.kind == 'stairs') {
        kind = NavEdgeKind.stairs;
      }

      VerticalDirection? dirAtoB;
      VerticalDirection? dirBtoA;
      if (kind != NavEdgeKind.walk) {
        if (toOrder > fromOrder) {
          dirAtoB = VerticalDirection.up;
          dirBtoA = VerticalDirection.down;
        } else if (toOrder < fromOrder) {
          dirAtoB = VerticalDirection.down;
          dirBtoA = VerticalDirection.up;
        }
      }

      addDirectedEdge(NavEdge(
        fromNodeId: edge.nodeIdA,
        toNodeId: edge.nodeIdB,
        distanceMeters: kind == NavEdgeKind.walk ? edge.effectiveDistance : _verticalTraversalCost,
        kind: kind,
        verticalDirection: dirAtoB,
        connectorNameAr: edge.connectorName,
      ));
      addDirectedEdge(NavEdge(
        fromNodeId: edge.nodeIdB,
        toNodeId: edge.nodeIdA,
        distanceMeters: kind == NavEdgeKind.walk ? edge.effectiveDistance : _verticalTraversalCost,
        kind: kind,
        verticalDirection: dirBtoA,
        connectorNameAr: edge.connectorName,
      ));
    }

    // --- الاتصال الرأسي: لو لسه مفيش حواف رأسية في جدول edges ---
    final connectorById = <int, VerticalConnectorModel>{
      for (final c in connectorModels) c.connectorId: c,
    };
    final stopsByConnector = <int, List<ConnectorStopModel>>{};
    for (final stop in connectorStopModels) {
      stopsByConnector.putIfAbsent(stop.connectorId, () => []).add(stop);
    }

    for (final entry in stopsByConnector.entries) {
      final connector = connectorById[entry.key];
      if (connector == null) continue;
      final kind = connector.connectorType == 'elevator'
          ? NavEdgeKind.elevator
          : NavEdgeKind.stairs;

      final stops = entry.value;
      for (var i = 0; i < stops.length; i++) {
        for (var j = 0; j < stops.length; j++) {
          if (i == j) continue;
          final fromNode = nodesById[stops[i].nodeId];
          final toNode = nodesById[stops[j].nodeId];
          if (fromNode == null || toNode == null) continue;

          final fromOrder = levelsById[fromNode.levelId]?.order ?? 0;
          final toOrder = levelsById[toNode.levelId]?.order ?? 0;
          if (fromOrder == toOrder) continue;

          // تجنب تكرار الحافة لو كانت موجودة بالفعل من جدول edges
          final alreadyExists = (adjacency[fromNode.id] ?? []).any((e) => e.toNodeId == toNode.id);
          if (alreadyExists) continue;

          addDirectedEdge(NavEdge(
            fromNodeId: fromNode.id,
            toNodeId: toNode.id,
            distanceMeters: _verticalTraversalCost,
            kind: kind,
            verticalDirection: toOrder > fromOrder
                ? VerticalDirection.up
                : VerticalDirection.down,
            connectorNameAr: connector.nameAr,
          ));
        }
      }
    }

    // --- الوجهات (destinations) ---
    final nodeIdsByDestination = <int, List<int>>{};
    for (final dn in destinationNodeModels) {
      nodeIdsByDestination.putIfAbsent(dn.destinationId, () => []).add(dn.nodeId);
    }
    final aliasesArByDestination = <int, List<String>>{};
    final aliasesEnByDestination = <int, List<String>>{};
    for (final a in destinationAliasModels) {
      final target =
          a.lang == 'ar' ? aliasesArByDestination : aliasesEnByDestination;
      target.putIfAbsent(a.destinationId, () => []).add(a.aliasText);
    }
    final destinations = destinationModels
        .where((d) => (nodeIdsByDestination[d.destinationId] ?? []).isNotEmpty)
        .map((d) => Destination(
              id: d.destinationId,
              nameAr: d.nameAr,
              nameEn: d.nameEn,
              nodeIds: nodeIdsByDestination[d.destinationId]!,
              aliasesAr: aliasesArByDestination[d.destinationId] ?? const [],
              aliasesEn: aliasesEnByDestination[d.destinationId] ?? const [],
              shortcutType: d.shortcutType,
            ))
        .toList();

    final graph = BuildingGraph(
      nodesById: nodesById,
      levelsById: levelsById,
      adjacency: adjacency,
      destinations: destinations,
      isFromCache: isFromCache,
    );

    return graph;
  }

  /// بناء BuildingGraph مباشرة من كائن JSON الناتج عن RPC get_building_graph
  BuildingGraph _buildGraphFromRpcData(Map<String, dynamic> rpc) {
    final levelsRaw = (rpc['levels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final nodesRaw = (rpc['nodes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final edgesRaw = (rpc['edges'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final destinationsRaw = (rpc['destinations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final levelsById = <String, NavLevel>{
      for (final l in levelsRaw)
        (l['level_id'] as String): NavLevel(
          id: l['level_id'] as String,
          nameAr: l['name_ar'] as String,
          nameEn: l['name_en'] as String?,
          order: (l['level_order'] as num?)?.toInt() ?? 0,
        ),
    };

    final nodesById = <int, NavNode>{
      for (final n in nodesRaw)
        (n['node_id'] as int): NavNode(
          id: n['node_id'] as int,
          levelId: n['level_id'] as String,
          nameAr: n['name_ar'] as String,
          nameEn: n['name_en'] as String?,
          type: (n['type'] == 'intersection')
              ? NavNodeType.intersection
              : NavNodeType.poi,
          facilityType: n['facility_type'] as String?,
          esp32Uuid: n['esp32_uuid'] as String?,
          x: (n['x'] as num?)?.toDouble(),
          y: (n['y'] as num?)?.toDouble(),
        ),
    };

    final adjacency = <int, List<NavEdge>>{};
    void addDirectedEdge(NavEdge edge) {
      adjacency.putIfAbsent(edge.fromNodeId, () => []).add(edge);
    }

    for (final e in edgesRaw) {
      final idA = e['node_id_a'] as int;
      final idB = e['node_id_b'] as int;
      final fromNode = nodesById[idA];
      final toNode = nodesById[idB];
      if (fromNode == null || toNode == null) continue;

      final dist = (e['distance_meters'] as num?)?.toDouble() ?? 5.0;
      final kindStr = (e['kind'] as String?) ?? 'walk';
      final connectorName = e['connector_name'] as String?;

      NavEdgeKind kind = NavEdgeKind.walk;
      if (kindStr == 'elevator') {
        kind = NavEdgeKind.elevator;
      } else if (kindStr == 'stairs') {
        kind = NavEdgeKind.stairs;
      }

      final fromOrder = levelsById[fromNode.levelId]?.order ?? 0;
      final toOrder = levelsById[toNode.levelId]?.order ?? 0;

      VerticalDirection? dirAtoB;
      VerticalDirection? dirBtoA;
      if (kind != NavEdgeKind.walk) {
        if (toOrder > fromOrder) {
          dirAtoB = VerticalDirection.up;
          dirBtoA = VerticalDirection.down;
        } else if (toOrder < fromOrder) {
          dirAtoB = VerticalDirection.down;
          dirBtoA = VerticalDirection.up;
        }
      }

      addDirectedEdge(NavEdge(
        fromNodeId: idA,
        toNodeId: idB,
        distanceMeters: kind == NavEdgeKind.walk ? dist : _verticalTraversalCost,
        kind: kind,
        verticalDirection: dirAtoB,
        connectorNameAr: connectorName,
      ));

      addDirectedEdge(NavEdge(
        fromNodeId: idB,
        toNodeId: idA,
        distanceMeters: kind == NavEdgeKind.walk ? dist : _verticalTraversalCost,
        kind: kind,
        verticalDirection: dirBtoA,
        connectorNameAr: connectorName,
      ));
    }

    final destinations = destinationsRaw.map((d) {
      final nodeIds = (d['node_ids'] as List?)?.map((id) => (id as num).toInt()).toList() ?? [];
      final aliasesAr = (d['aliases_ar'] as List?)?.map((a) => a.toString()).toList() ?? [];
      final aliasesEn = (d['aliases_en'] as List?)?.map((a) => a.toString()).toList() ?? [];

      return Destination(
        id: d['destination_id'] as int,
        nameAr: d['name_ar'] as String,
        nameEn: d['name_en'] as String?,
        nodeIds: nodeIds,
        aliasesAr: aliasesAr,
        aliasesEn: aliasesEn,
        shortcutType: d['shortcut_type'] as String?,
      );
    }).where((d) => d.nodeIds.isNotEmpty).toList();

    return BuildingGraph(
      nodesById: nodesById,
      levelsById: levelsById,
      adjacency: adjacency,
      destinations: destinations,
      isFromCache: _dataSource.usedCacheInLastFetch,
    );
  }
}
