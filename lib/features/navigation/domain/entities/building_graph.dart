import 'nav_node.dart';
import 'nav_edge.dart';
import 'nav_level.dart';
import 'destination.dart';

/// الـ graph الموحّد الكامل للمبنى — كل الأدوار مع بعض، بما فيها حواف
/// الاتصال الرأسي (أسانسير/سلم) كحواف عادية بين الأدوار.
///
/// دي أهم كيان في الـ domain layer: كل حاجة تانية (البحث، حساب المسار)
/// بتشتغل على النسخة دي بدل ما تتكلم مع Supabase مباشرة.
///
/// ملاحظة: الأسماء البديلة للعقد (node_aliases) اتستبدلت بـ [destinations]
/// لأن البحث لازم يشتغل على "أماكن منطقية" مش على هوية العقدة
/// الفيزيائية مباشرة (راجع توثيق [Destination]).
class BuildingGraph {
  final Map<int, NavNode> nodesById;
  final Map<String, NavLevel> levelsById;
  final Map<int, List<NavEdge>> adjacency;

  /// الوجهات القابلة للبحث (منفصلة عن هوية العقدة الفيزيائية — راجع
  /// توثيق [Destination]).
  final List<Destination> destinations;

  /// true لو النسخة دي جت من الكاش المحلي (مفيش نت وقت التحميل) مش من
  /// سوبابيز مباشرة. الطبقات الأعلى (Controller/UI) تقدر تستخدمها عشان
  /// تنبّه المستخدم إنه شايف بيانات مخزّنة بدل الأحدث.
  final bool isFromCache;

  BuildingGraph({
    required this.nodesById,
    required this.levelsById,
    required this.adjacency,
    this.destinations = const [],
    this.isFromCache = false,
  });

  List<NavEdge> neighboursOf(int nodeId) => adjacency[nodeId] ?? const [];

  NavNode? nodeById(int id) => nodesById[id];

  Iterable<NavNode> get allNodes => nodesById.values;

  Iterable<NavLevel> get allLevels => levelsById.values;

  /// كل العقد المعلّمة بنوع المرفق ده (زي 'elevator'، 'restroom_male') —
  /// النظام الثابت لنقاط المرافق، منفصل تمامًا عن [destinations] القابلة
  /// للبحث. راجع توثيق [NavNode.facilityType].
  Iterable<NavNode> nodesByFacilityType(String facilityType) =>
      nodesById.values.where((n) => n.facilityType == facilityType);
}
