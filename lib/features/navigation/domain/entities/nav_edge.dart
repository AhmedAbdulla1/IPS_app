/// اتجاه التنقل الرأسي بين الأدوار (لو الحافة دي أسانسير أو سلم)
enum VerticalDirection { up, down }

/// نوع الحافة: مشي عادي على نفس الدور، أو اتصال رأسي (أسانسير/سلم)
enum NavEdgeKind { walk, elevator, stairs }

/// حافة (edge) بين نقطتين في الـ graph — اتجاه واحد (directed).
/// الحواف العادية (walk) بتتحط مرتين (A→B و B→A) وقت بناء الـ graph.
/// حواف الاتصال الرأسي كمان بتتحط في الاتجاهين، لكن كل واحدة عندها
/// [verticalDirection] مختلف (up من تحت لفوق، down من فوق لتحت).
class NavEdge {
  final int fromNodeId;
  final int toNodeId;
  final double distanceMeters;
  final NavEdgeKind kind;
  final VerticalDirection? verticalDirection;

  /// اسم الموصل الرأسي (لو الحافة دي أسانسير/سلم) — مفيد للعرض في الـ UI
  /// (زي "خُد أسانسير أ").
  final String? connectorNameAr;

  const NavEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.distanceMeters,
    this.kind = NavEdgeKind.walk,
    this.verticalDirection,
    this.connectorNameAr,
  });

  bool get isVertical => kind != NavEdgeKind.walk;
}
