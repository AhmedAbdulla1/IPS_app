import '../../domain/entities/building_graph.dart';
import '../../domain/entities/nav_edge.dart';
import '../../domain/entities/nav_node.dart';
import '../../domain/entities/nav_level.dart';
import '../../domain/entities/destination.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../datasources/supabase_navigation_datasource.dart';
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
  Future<BuildingGraph> loadGraph({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedGraph != null) {
      return _cachedGraph!;
    }

    _dataSource.resetCacheFlag();

    // بنبدأ كل الطلبات مع بعض (من غير await فوري) عشان تتنفذ بالتوازي،
    // وبعدين نستنى كل واحدة على حدة فنحتفظ بالنوع (type) بتاعها.
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

    // --- الأدوار والنقاط ---
    final levelsById = <String, NavLevel>{
      for (final m in levelModels) m.levelId: m.toEntity(),
    };
    final nodesById = <int, NavNode>{
      for (final m in nodeModels) m.nodeId: m.toEntity(),
    };

    // --- الأسماء البديلة اتشالت (node_aliases اتستبدل بـ destinations) ---

    // --- الحواف: كل حافة عادية بتتحط في الاتجاهين ---
    final adjacency = <int, List<NavEdge>>{};
    void addDirectedEdge(NavEdge edge) {
      adjacency.putIfAbsent(edge.fromNodeId, () => []).add(edge);
    }

    for (final edge in edgeModels) {
      addDirectedEdge(NavEdge(
        fromNodeId: edge.nodeIdA,
        toNodeId: edge.nodeIdB,
        distanceMeters: edge.effectiveDistance,
      ));
      addDirectedEdge(NavEdge(
        fromNodeId: edge.nodeIdB,
        toNodeId: edge.nodeIdA,
        distanceMeters: edge.effectiveDistance,
      ));
    }

    // --- الاتصال الرأسي: كل زوج محطات لنفس الموصل بيتوصلوا ببعض مباشرة ---
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
          if (fromOrder == toOrder) continue; // نفس الدور، مش حافة رأسية

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

    // --- الوجهات (destinations): تجميع كل وجهة مع عقدها وaliases بتاعتها ---
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
      isFromCache: _dataSource.usedCacheInLastFetch,
    );

    _cachedGraph = graph;
    return graph;
  }
}
