import 'dart:math' as math;
import 'package:flutter/material.dart' hide VerticalDirection;
import '../../domain/entities/building_graph.dart';
import '../../domain/entities/nav_edge.dart';
import '../../domain/entities/nav_node.dart';
import '../../domain/entities/path_step.dart';

/// ويدجت كانفاس تفاعلي يرسم المسار الحقيقي وفق الإحداثيات المترية الفعلية للـ Nodes
/// يدعم بالكامل مسارات الأدوار المتعددة مع التبديل التلقائي أو اليدوي بين الأدوار
class RouteMetricCanvas extends StatefulWidget {
  final BuildingGraph? graph;
  final List<PathStep> currentPath;
  final int currentStepIndex;
  final math.Point<double>? userCoordinates;
  final int? currentUserFloor;
  final double deviceHeading;
  final bool isDark;

  const RouteMetricCanvas({
    super.key,
    required this.graph,
    required this.currentPath,
    required this.currentStepIndex,
    required this.userCoordinates,
    this.currentUserFloor,
    required this.deviceHeading,
    required this.isDark,
  });

  @override
  State<RouteMetricCanvas> createState() => _RouteMetricCanvasState();
}

class _FloorTabInfo {
  final String levelId;
  final int order;
  final String name;
  final int nodeCount;
  final bool isCurrentStepHere;

  const _FloorTabInfo({
    required this.levelId,
    required this.order,
    required this.name,
    required this.nodeCount,
    required this.isCurrentStepHere,
  });
}

class _FloorPathNode {
  final NavNode node;
  final PathStep step;
  final int globalIndex;
  final VerticalDirection? verticalDirection;
  final String? verticalTargetName;

  const _FloorPathNode({
    required this.node,
    required this.step,
    required this.globalIndex,
    this.verticalDirection,
    this.verticalTargetName,
  });
}

class _RouteMetricCanvasState extends State<RouteMetricCanvas> {
  final TransformationController _transformController = TransformationController();
  String? _selectedLevelId;
  bool _autoFollow = true;

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentPath.isEmpty || widget.graph == null) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: const Text(
          'لا يوجد مسار نشط حالياً للعرض',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final graph = widget.graph!;
    final path = widget.currentPath;

    // استخراج معلومات جميع الأدوار الموجودة في المسار
    final floorMap = <String, _FloorTabInfo>{};
    final distinctLevelIds = <String>[];

    final safeStepIdx = widget.currentStepIndex.clamp(0, path.length - 1);
    final activeStepNodeId = path[safeStepIdx].nodeId;
    final activeNode = graph.nodeById(activeStepNodeId);
    final activeLevelId = activeNode?.levelId;

    for (var i = 0; i < path.length; i++) {
      final step = path[i];
      final node = graph.nodeById(step.nodeId);
      if (node == null) continue;

      final lvlId = node.levelId;
      if (!floorMap.containsKey(lvlId)) {
        distinctLevelIds.add(lvlId);
        final navLvl = graph.levelsById[lvlId];
        final order = navLvl?.order ?? int.tryParse(lvlId) ?? 0;
        final name = (navLvl != null && navLvl.nameAr.trim().isNotEmpty)
            ? navLvl.nameAr.trim()
            : 'الدور $order';

        floorMap[lvlId] = _FloorTabInfo(
          levelId: lvlId,
          order: order,
          name: name,
          nodeCount: 1,
          isCurrentStepHere: lvlId == activeLevelId,
        );
      } else {
        final existing = floorMap[lvlId]!;
        floorMap[lvlId] = _FloorTabInfo(
          levelId: lvlId,
          order: existing.order,
          name: existing.name,
          nodeCount: existing.nodeCount + 1,
          isCurrentStepHere: lvlId == activeLevelId,
        );
      }
    }

    // إدارة التتبع التلقائي للدور النشط
    if (_autoFollow && activeLevelId != null && floorMap.containsKey(activeLevelId)) {
      _selectedLevelId = activeLevelId;
    } else if (_selectedLevelId == null || !floorMap.containsKey(_selectedLevelId)) {
      _selectedLevelId = activeLevelId ?? (distinctLevelIds.isNotEmpty ? distinctLevelIds.first : null);
    }

    final currentViewingLevelId = _selectedLevelId;
    final currentViewingFloorInfo = floorMap[currentViewingLevelId];

    // استخراج نودز وخطوات الدور المختار فقط
    final floorPathNodes = <_FloorPathNode>[];
    for (var i = 0; i < path.length; i++) {
      final step = path[i];
      final node = graph.nodeById(step.nodeId);
      if (node == null || node.levelId != currentViewingLevelId) continue;

      VerticalDirection? vDir = step.verticalDirection;
      String? vTargetName;

      // فحص إذا كانت هذه النقطة محطة انتقال رأسي (مصعد/سلم) للدور التالي
      if (vDir == null && i < path.length - 1) {
        final nextStep = path[i + 1];
        if (nextStep.verticalDirection != null) {
          vDir = nextStep.verticalDirection;
          final nextNode = graph.nodeById(nextStep.nodeId);
          final nextNavLvl = nextNode != null ? graph.levelsById[nextNode.levelId] : null;
          vTargetName = nextNavLvl?.nameAr ?? 'الدور التالي';
        }
      }

      floorPathNodes.add(_FloorPathNode(
        node: node,
        step: step,
        globalIndex: i,
        verticalDirection: vDir,
        verticalTargetName: vTargetName,
      ));
    }

    final isUserOnViewingFloor = widget.currentUserFloor == null ||
        (currentViewingFloorInfo != null && widget.currentUserFloor == currentViewingFloorInfo.order);

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF16181D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط أدوات الكانفاس العلوي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF20232B) : const Color(0xFFEEF2F6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.architecture_rounded, size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    currentViewingFloorInfo != null
                        ? 'المسار المتري (${currentViewingFloorInfo.name})'
                        : 'المسار المتري الحقيقي',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.userCoordinates != null && isUserOnViewingFloor) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(120)),
                    ),
                    child: Text(
                      'X: ${widget.userCoordinates!.x.toStringAsFixed(1)} | Y: ${widget.userCoordinates!.y.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ] else if (widget.currentUserFloor != null && !isUserOnViewingFloor) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B).withAlpha(100)),
                    ),
                    child: Text(
                      'المستخدم بدور ${widget.currentUserFloor}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.fit_screen_rounded, size: 16),
                  onPressed: _resetZoom,
                  tooltip: 'إعادة ملاءمة الكانفاس',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),

          // شريط أزرار اختيار الأدوار (يظهر فقط إذا كان المسار يحتوي على أكثر من دور)
          if (distinctLevelIds.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1B1E26) : const Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(
                    color: widget.isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: distinctLevelIds.map((lvlId) {
                          final info = floorMap[lvlId]!;
                          final isSelected = lvlId == currentViewingLevelId;
                          final isStepHere = lvlId == activeLevelId;

                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedLevelId = lvlId;
                                  _autoFollow = (lvlId == activeLevelId);
                                  _resetZoom();
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFD97706)
                                      : (widget.isDark ? Colors.white10 : Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFD97706)
                                        : (isStepHere
                                            ? const Color(0xFFF59E0B).withAlpha(160)
                                            : Colors.transparent),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isStepHere)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.white : const Color(0xFFF59E0B),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '${info.name} (${info.nodeCount})',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : (widget.isDark ? Colors.white70 : Colors.black87),
                                        fontSize: 10.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  if (!_autoFollow)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _autoFollow = true;
                          _selectedLevelId = activeLevelId;
                          _resetZoom();
                        });
                      },
                      icon: const Icon(Icons.sync_rounded, size: 12),
                      label: const Text('تتبع تلقائي', style: TextStyle(fontSize: 10)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF3B82F6),
                      ),
                    ),
                ],
              ),
            ),

          // الكانفاس التفاعلي
          SizedBox(
            height: 220,
            child: ClipRRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 360.0;
                  return InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CustomPaint(
                      size: Size(canvasWidth, 220),
                      painter: _MetricMapPainter(
                        floorPathNodes: floorPathNodes,
                        currentStepIndex: widget.currentStepIndex,
                        userCoordinates: isUserOnViewingFloor ? widget.userCoordinates : null,
                        deviceHeading: widget.deviceHeading,
                        isDark: widget.isDark,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // شريط قائمة العقد والإحداثيات أسفل الكانفاس مع إشارات واضحة للأدوار والانتقال الرأسي
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E2128) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.currentPath.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final step = widget.currentPath[index];
                final node = widget.graph?.nodeById(step.nodeId);
                final navLvl = node != null ? widget.graph?.levelsById[node.levelId] : null;
                final floorOrder = navLvl?.order ?? (node != null ? int.tryParse(node.levelId) : null) ?? 0;

                final isTarget = index == widget.currentStepIndex;
                final isPassed = index < widget.currentStepIndex;
                final isVerticalStep = step.verticalDirection != null;
                final isSameFloorAsViewing = node?.levelId == currentViewingLevelId;

                Color badgeBg = widget.isDark ? Colors.white10 : Colors.black12;
                Color badgeBorder = Colors.transparent;
                Color textColor = widget.isDark ? Colors.white70 : Colors.black87;

                if (isTarget) {
                  badgeBg = const Color(0xFFF59E0B).withAlpha(50);
                  badgeBorder = const Color(0xFFF59E0B);
                  textColor = const Color(0xFFF59E0B);
                } else if (isPassed) {
                  badgeBg = const Color(0xFF10B981).withAlpha(40);
                  textColor = const Color(0xFF10B981);
                }

                final coordsStr = (node?.x != null && node?.y != null)
                    ? '(${node!.x!.toStringAsFixed(1)}, ${node.y!.toStringAsFixed(1)})'
                    : '(--, --)';

                return InkWell(
                  onTap: () {
                    if (node?.levelId != null && node!.levelId != _selectedLevelId) {
                      setState(() {
                        _selectedLevelId = node.levelId;
                        _autoFollow = (node.levelId == activeLevelId);
                        _resetZoom();
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isTarget
                            ? badgeBorder
                            : (isSameFloorAsViewing ? const Color(0xFF3B82F6).withAlpha(120) : badgeBorder),
                        width: isTarget || isSameFloorAsViewing ? 1.2 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isVerticalStep)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              step.verticalDirection == VerticalDirection.up
                                  ? Icons.elevator_rounded
                                  : Icons.stairs_rounded,
                              size: 13,
                              color: const Color(0xFF3B82F6),
                            ),
                          )
                        else if (isTarget)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.my_location_rounded, size: 12, color: Color(0xFFF59E0B)),
                          )
                        else if (isPassed)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.check_rounded, size: 12, color: Color(0xFF10B981)),
                          ),
                        Text(
                          'د$floorOrder #${step.nodeId} $coordsStr',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
                            color: textColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter يرسم المسار بمساقط حقيقية متناسبة مع أبعاد الدور المختار
class _MetricMapPainter extends CustomPainter {
  final List<_FloorPathNode> floorPathNodes;
  final int currentStepIndex;
  final math.Point<double>? userCoordinates;
  final double deviceHeading;
  final bool isDark;

  _MetricMapPainter({
    required this.floorPathNodes,
    required this.currentStepIndex,
    required this.userCoordinates,
    required this.deviceHeading,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (floorPathNodes.isEmpty) return;

    // حساب حدود الـ (X, Y) المترية لجميع نودز هذا الدور ونقطة المستخدم
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final fn in floorPathNodes) {
      final n = fn.node;
      if (n.x != null && n.y != null) {
        if (n.x! < minX) minX = n.x!;
        if (n.x! > maxX) maxX = n.x!;
        if (n.y! < minY) minY = n.y!;
        if (n.y! > maxY) maxY = n.y!;
      }
    }

    if (userCoordinates != null) {
      if (userCoordinates!.x < minX) minX = userCoordinates!.x;
      if (userCoordinates!.x > maxX) maxX = userCoordinates!.x;
      if (userCoordinates!.y < minY) minY = userCoordinates!.y;
      if (userCoordinates!.y > maxY) maxY = userCoordinates!.y;
    }

    if (minX == double.infinity) {
      minX = 0;
      maxX = 20;
      minY = 0;
      maxY = 20;
    }

    // إضافة هامش متري بمقدار 2.5 متر على الأقل حول المسار
    const marginMeters = 2.5;
    minX -= marginMeters;
    maxX += marginMeters;
    minY -= marginMeters;
    maxY += marginMeters;

    final rangeX = (maxX - minX).clamp(5.0, 500.0);
    final rangeY = (maxY - minY).clamp(5.0, 500.0);

    // الحفاظ التام على التناسب المتري (Aspect Ratio 1:1)
    const padding = 20.0;
    final availableWidth = size.width - padding * 2;
    final availableHeight = size.height - padding * 2;

    // المرجعية الهندسية للمبنى:
    // - اتجاه الشمال هو لأعلى الكانفاس (نحو أقل X).
    // - محور X بيزيد لتحت (رأسي py).
    // - محور Y بيزيد لليمين (أفقي px).
    final scaleX = availableWidth / rangeY;
    final scaleY = availableHeight / rangeX;
    final scale = math.min(scaleX, scaleY);

    final offsetX = padding + (availableWidth - rangeY * scale) / 2;
    final offsetY = padding + (availableHeight - rangeX * scale) / 2;

    Offset toPixel(double x, double y) {
      final px = offsetX + (y - minY) * scale;
      final py = offsetY + (x - minX) * scale;
      return Offset(px, py);
    }

    // 1. رسم شبكة مترية خفيفة في الخلفية
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(12)
      ..strokeWidth = 1.0;

    for (double gx = (minX / 5).floor() * 5.0; gx <= maxX; gx += 5.0) {
      final p1 = toPixel(gx, minY);
      final p2 = toPixel(gx, maxY);
      canvas.drawLine(p1, p2, gridPaint);
    }
    for (double gy = (minY / 5).floor() * 5.0; gy <= maxY; gy += 5.0) {
      final p1 = toPixel(minX, gy);
      final p2 = toPixel(maxX, gy);
      canvas.drawLine(p1, p2, gridPaint);
    }

    // رسم علامة الشمال (N ↑)
    _drawNorthIndicator(canvas, Offset(padding + 12, padding + 12));

    // 2. رسم خطوط المسار (Edges) بين النودز المتتالية في نفس الدور
    final passedLinePaint = Paint()
      ..color = const Color(0xFF10B981).withAlpha(160)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final activeLinePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final upcomingLinePaint = Paint()
      ..color = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < floorPathNodes.length - 1; i++) {
      final fn1 = floorPathNodes[i];
      final fn2 = floorPathNodes[i + 1];

      // نرسم خط فقط إذا كانت النقطتان متتاليتين في المسار الأصلي أيضاً
      if (fn2.globalIndex != fn1.globalIndex + 1) continue;
      if (fn1.node.x == null || fn1.node.y == null || fn2.node.x == null || fn2.node.y == null) continue;

      final p1 = toPixel(fn1.node.x!, fn1.node.y!);
      final p2 = toPixel(fn2.node.x!, fn2.node.y!);

      Paint edgePaint;
      if (fn2.globalIndex < currentStepIndex) {
        edgePaint = passedLinePaint;
      } else if (fn2.globalIndex == currentStepIndex) {
        edgePaint = activeLinePaint;
      } else {
        edgePaint = upcomingLinePaint;
      }

      canvas.drawLine(p1, p2, edgePaint);

      final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      _drawArrowHead(canvas, midPoint, angle, edgePaint.color);
    }

    // 3. رسم النودز
    for (int i = 0; i < floorPathNodes.length; i++) {
      final fn = floorPathNodes[i];
      final n = fn.node;
      if (n.x == null || n.y == null) continue;
      final p = toPixel(n.x!, n.y!);

      final globalIdx = fn.globalIndex;
      final isStart = globalIdx == 0;
      final isDest = fn.step == floorPathNodes.last.step && fn.verticalDirection == null;
      final isTarget = globalIdx == currentStepIndex;
      final isPassed = globalIdx < currentStepIndex;
      final isVertical = fn.verticalDirection != null;

      Color nodeColor;
      double radius = 7.0;

      if (isVertical) {
        nodeColor = const Color(0xFF3B82F6); // نود انتقال رأسي (أزرق مصعد)
        radius = 9.0;
      } else if (isStart) {
        nodeColor = const Color(0xFF10B981);
        radius = 8.5;
      } else if (isDest) {
        nodeColor = const Color(0xFFEF4444);
        radius = 9.0;
      } else if (isTarget) {
        nodeColor = const Color(0xFFF59E0B);
        radius = 8.5;
      } else if (isPassed) {
        nodeColor = const Color(0xFF10B981).withAlpha(180);
      } else {
        nodeColor = const Color(0xFF64748B);
      }

      // هالة نبضية حول النود المستهدف أو نقطة المصعد
      if (isTarget) {
        final glowPaint = Paint()
          ..color = const Color(0xFFF59E0B).withAlpha(80)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 16.0, glowPaint);
      } else if (isVertical) {
        final vGlow = Paint()
          ..color = const Color(0xFF3B82F6).withAlpha(70)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 15.0, vGlow);
      }

      final circlePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, radius, circlePaint);

      final borderPaint = Paint()
        ..color = isDark ? Colors.white : Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(p, radius, borderPaint);

      // تسمية رقم النود أو أيقونة الانتقال فوقه
      String labelText = '#${n.id}';
      if (isVertical) {
        labelText = fn.verticalDirection == VerticalDirection.up ? '⬆ مصعد' : '⬇ سلم';
      }

      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: isVertical
              ? const Color(0xFF3B82F6)
              : (isDark ? Colors.white70 : Colors.black87),
          fontSize: 9,
          fontWeight: isTarget || isVertical ? FontWeight.bold : FontWeight.normal,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(p.dx - textPainter.width / 2, p.dy - radius - 12));
    }

    // 4. رسم موقع المستخدم اللحظي المستمر (User Position & Heading Beam)
    if (userCoordinates != null) {
      final userP = toPixel(userCoordinates!.x, userCoordinates!.y);

      final headingRad = (deviceHeading - 90) * math.pi / 180.0;
      final beamLength = 26.0;
      final beamEnd = Offset(
        userP.dx + beamLength * math.cos(headingRad),
        userP.dy + beamLength * math.sin(headingRad),
      );

      final beamPaint = Paint()
        ..color = const Color(0xFF8B5CF6).withAlpha(180)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(userP, beamEnd, beamPaint);

      _drawArrowHead(canvas, beamEnd, headingRad, const Color(0xFF8B5CF6));

      final userGlow = Paint()
        ..color = const Color(0xFF8B5CF6).withAlpha(80)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(userP, 12.0, userGlow);

      final userDot = Paint()
        ..color = const Color(0xFF8B5CF6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(userP, 6.0, userDot);

      final userBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(userP, 6.0, userBorder);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset point, double angle, Color color) {
    const arrowSize = 6.0;
    final path = Path();
    path.moveTo(
      point.dx + arrowSize * math.cos(angle),
      point.dy + arrowSize * math.sin(angle),
    );
    path.lineTo(
      point.dx + arrowSize * math.cos(angle + 2.5),
      point.dy + arrowSize * math.sin(angle + 2.5),
    );
    path.lineTo(
      point.dx + arrowSize * math.cos(angle - 2.5),
      point.dy + arrowSize * math.sin(angle - 2.5),
    );
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  void _drawNorthIndicator(Canvas canvas, Offset position) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF20232B).withAlpha(220) : Colors.white.withAlpha(220)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(position, 13.0, bgPaint);
    canvas.drawCircle(position, 13.0, borderPaint);

    final arrowPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(position + const Offset(0, 5), position + const Offset(0, -6), arrowPaint);
    final path = Path()
      ..moveTo(position.dx - 3, position.dy - 3)
      ..lineTo(position.dx, position.dy - 7)
      ..lineTo(position.dx + 3, position.dy - 3);
    canvas.drawPath(path, arrowPaint);

    final textSpan = TextSpan(
      text: 'N',
      style: const TextStyle(
        color: Color(0xFFEF4444),
        fontSize: 7.5,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(position.dx - tp.width / 2, position.dy + 1));
  }

  @override
  bool shouldRepaint(covariant _MetricMapPainter oldDelegate) {
    return oldDelegate.currentStepIndex != currentStepIndex ||
        oldDelegate.userCoordinates != userCoordinates ||
        oldDelegate.deviceHeading != deviceHeading ||
        oldDelegate.floorPathNodes != floorPathNodes ||
        oldDelegate.isDark != isDark;
  }
}
