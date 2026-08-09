import 'nav_edge.dart';

/// خطوة واحدة في المسار الناتج من [FindPathUseCase] — تمثيل Domain نقي
/// لمخرجات الـ A*، مستقل عن أي شكل بيانات قديم في التطبيق.
class PathStep {
  final int nodeId;

  /// اتجاه المشي بالدرجات (0-360) — 0 دايمًا في أول نقطة (نقطة البداية)
  /// وفي أي حافة رأسية (أسانسير/سلم)، لأن الاتجاه مش له معنى هناك.
  final double heading;

  /// لو الحافة اللي وصلنا بيها للنقطة دي كانت أسانسير/سلم، بيتحدد هنا
  /// الاتجاه (فوق/تحت). null يعني مشي عادي على نفس الدور.
  final VerticalDirection? verticalDirection;

  final bool isStartingNode;

  /// طول الحافة اللي وصلنا بيها للنقطة دي (بالمتر) — 0 لنقطة البداية.
  final double legDistanceMeters;

  const PathStep({
    required this.nodeId,
    this.heading = 0,
    this.verticalDirection,
    this.isStartingNode = false,
    this.legDistanceMeters = 0,
  });

  @override
  String toString() =>
      'PathStep(node=$nodeId, heading=$heading, vertical=$verticalDirection)';
}
