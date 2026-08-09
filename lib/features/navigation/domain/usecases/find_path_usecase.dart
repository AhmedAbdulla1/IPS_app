import 'dart:math' as math;

import '../entities/building_graph.dart';
import '../entities/nav_edge.dart';
import '../entities/path_step.dart';
import 'heading_calculator.dart';
import 'path_not_found_exception.dart';

/// A* الموحّد الجديد — بيشتغل على الـ graph كامل (كل الأدوار مع بعض) دفعة
/// واحدة، ومعامل الاتصال الرأسي (أسانسير/سلم) كحافة عادية زي أي حافة تانية.
/// من غير أي "قفزة" خاصة زي الخوارزمية القديمة.
class FindPathUseCase {
  /// عقوبة تقريبية (بالمتر) بتتضاف للـ heuristic لكل فرق دور، عشان الـ
  /// heuristic يفضل معقول لما النقطتين في أدوار مختلفة (المسافة الإقليدية
  /// وحدها مش كافية هنا لأن كل دور له إحداثيات محلية منفصلة).
  /// قابلة للتعديل لو المسارات الناتجة طلعت غريبة بعد ما تتحط بيانات حقيقية.
  static const double _levelChangePenalty = 15.0;

  List<PathStep> call(
    BuildingGraph graph,
    int startNodeId,
    int destinationNodeId,
  ) {
    if (startNodeId == destinationNodeId) {
      return [PathStep(nodeId: startNodeId, isStartingNode: true)];
    }

    final gScore = <int, double>{startNodeId: 0};
    final fScore = <int, double>{
      startNodeId: _heuristic(graph, startNodeId, destinationNodeId),
    };
    final cameFromNode = <int, int>{};
    final cameFromEdge = <int, NavEdge>{};
    final open = <int>{startNodeId};
    final closed = <int>{};

    while (open.isNotEmpty) {
      final current = open.reduce(
        (a, b) => (fScore[a] ?? double.infinity) <= (fScore[b] ?? double.infinity) ? a : b,
      );

      if (current == destinationNodeId) {
        return _reconstructPath(
          graph,
          cameFromNode,
          cameFromEdge,
          startNodeId,
          destinationNodeId,
        );
      }

      open.remove(current);
      closed.add(current);

      for (final edge in graph.neighboursOf(current)) {
        final neighbourId = edge.toNodeId;
        if (closed.contains(neighbourId)) continue;

        final tentativeG = (gScore[current] ?? double.infinity) + edge.distanceMeters;
        if (tentativeG < (gScore[neighbourId] ?? double.infinity)) {
          cameFromNode[neighbourId] = current;
          cameFromEdge[neighbourId] = edge;
          gScore[neighbourId] = tentativeG;
          fScore[neighbourId] =
              tentativeG + _heuristic(graph, neighbourId, destinationNodeId);
          open.add(neighbourId);
        }
      }
    }

    throw PathNotFoundException(
      'لا يوجد مسار متاح بين النقطة $startNodeId والنقطة $destinationNodeId',
    );
  }

  double _heuristic(BuildingGraph graph, int fromId, int toId) {
    final from = graph.nodeById(fromId);
    final to = graph.nodeById(toId);
    if (from == null || to == null) return 0;

    double distance = 0;
    if (from.x != null && from.y != null && to.x != null && to.y != null) {
      distance = math.sqrt(
        math.pow(to.x! - from.x!, 2) + math.pow(to.y! - from.y!, 2),
      );
    }

    if (from.levelId != to.levelId) {
      final fromOrder = graph.levelsById[from.levelId]?.order ?? 0;
      final toOrder = graph.levelsById[to.levelId]?.order ?? 0;
      distance += (fromOrder - toOrder).abs() * _levelChangePenalty;
    }

    return distance;
  }

  List<PathStep> _reconstructPath(
    BuildingGraph graph,
    Map<int, int> cameFromNode,
    Map<int, NavEdge> cameFromEdge,
    int startNodeId,
    int destinationNodeId,
  ) {
    final nodeIdsReversed = <int>[destinationNodeId];
    var current = destinationNodeId;
    while (current != startNodeId) {
      current = cameFromNode[current]!;
      nodeIdsReversed.add(current);
    }
    final orderedIds = nodeIdsReversed.reversed.toList();

    final steps = <PathStep>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final nodeId = orderedIds[i];
      if (i == 0) {
        steps.add(PathStep(nodeId: nodeId, isStartingNode: true));
        continue;
      }

      final edge = cameFromEdge[nodeId]!;
      double heading = 0;
      if (!edge.isVertical) {
        final fromNode = graph.nodeById(edge.fromNodeId);
        final toNode = graph.nodeById(edge.toNodeId);
        if (fromNode?.x != null &&
            fromNode?.y != null &&
            toNode?.x != null &&
            toNode?.y != null) {
          heading = calculateHeading(
            xA: fromNode!.x!,
            yA: fromNode.y!,
            xB: toNode!.x!,
            yB: toNode.y!,
          );
        }
      }

      steps.add(PathStep(
        nodeId: nodeId,
        heading: heading,
        verticalDirection: edge.verticalDirection,
        legDistanceMeters: edge.distanceMeters,
      ));
    }

    return steps;
  }
}
