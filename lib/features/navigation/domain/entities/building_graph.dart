import 'nav_node.dart';
import 'nav_edge.dart';
import 'nav_level.dart';
import 'node_alias.dart';

/// الـ graph الموحّد الكامل للمبنى — كل الأدوار مع بعض، بما فيها حواف
/// الاتصال الرأسي (أسانسير/سلم) كحواف عادية بين الأدوار.
///
/// دي أهم كيان في الـ domain layer: كل حاجة تانية (البحث، حساب المسار)
/// بتشتغل على النسخة دي بدل ما تتكلم مع Supabase مباشرة.
class BuildingGraph {
  final Map<int, NavNode> nodesById;
  final Map<String, NavLevel> levelsById;
  final Map<int, List<NavEdge>> _adjacency;
  final Map<int, List<NodeAlias>> _aliasesByNode;

  BuildingGraph({
    required this.nodesById,
    required this.levelsById,
    required Map<int, List<NavEdge>> adjacency,
    required Map<int, List<NodeAlias>> aliasesByNode,
  })  : _adjacency = adjacency,
        _aliasesByNode = aliasesByNode;

  List<NavEdge> neighboursOf(int nodeId) => _adjacency[nodeId] ?? const [];

  List<NodeAlias> aliasesOf(int nodeId) => _aliasesByNode[nodeId] ?? const [];

  NavNode? nodeById(int id) => nodesById[id];

  Iterable<NavNode> get allNodes => nodesById.values;

  Iterable<NavLevel> get allLevels => levelsById.values;
}
