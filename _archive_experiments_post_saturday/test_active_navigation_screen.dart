import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../controllers/navigation_controller.dart';
import '../services/navigation_telemetry_recorder.dart';
import '../widgets/test/route_metric_canvas.dart';
import 'active_navigation_screen.dart';

/// شاشة الملاحة النشطة المخصصة لفلافور الاختبار (Test Flavor)
/// تتيح للمهندس والمختبر الميداني فحص كامل التيليميتري بدون تخمين ما يحدث في الخلفية
class TestActiveNavigationScreen extends StatefulWidget {
  final NavigationScreenController controller;
  final AppPalette palette;

  const TestActiveNavigationScreen({
    super.key,
    required this.controller,
    required this.palette,
  });

  @override
  State<TestActiveNavigationScreen> createState() => _TestActiveNavigationScreenState();
}

class _TestActiveNavigationScreenState extends State<TestActiveNavigationScreen>
    with SingleTickerProviderStateMixin {
  bool _showProductionPreview = false;
  AnimationController? _walkAnimController;
  math.Point<double>? _simulatedUserCoords;
  math.Point<double>? _animStartCoords;
  math.Point<double>? _animEndCoords;
  bool _isAutoWalking = false;

  NavigationTelemetryRecorder? get _recorder =>
      Get.isRegistered<NavigationTelemetryRecorder>()
          ? Get.find<NavigationTelemetryRecorder>()
          : null;

  @override
  void initState() {
    super.initState();
    _walkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(() {
      if (_animStartCoords != null && _animEndCoords != null) {
        final t = Curves.easeInOut.transform(_walkAnimController!.value);
        final curX = _animStartCoords!.x + (_animEndCoords!.x - _animStartCoords!.x) * t;
        final curY = _animStartCoords!.y + (_animEndCoords!.y - _animStartCoords!.y) * t;
        setState(() {
          _simulatedUserCoords = math.Point<double>(curX, curY);
        });
      }
    })..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_isAutoWalking) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && _isAutoWalking) {
              _advanceAutoWalk();
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _walkAnimController?.dispose();
    super.dispose();
  }

  int? _simulatedFloor;

  void _animateToTargetNode(int targetIndex) {
    final graph = widget.controller.navigationRepository.cachedGraph;
    final path = widget.controller.currentPath;
    if (graph == null || path.isEmpty || targetIndex >= path.length) return;

    final targetStep = path[targetIndex];
    final targetNode = graph.nodeById(targetStep.nodeId);
    if (targetNode?.x == null || targetNode?.y == null) return;

    final navLevel = graph.levelsById[targetNode!.levelId];
    final targetFloor = navLevel?.order ?? int.tryParse(targetNode.levelId);

    // إذا كانت النقلة بين دورين مختلفين (مصعد/سلم)، نحدث الدور وننتقل مباشرة دون طيران بين مستويات إحداثيات مختلفة
    final prevStep = targetIndex > 0 ? path[targetIndex - 1] : null;
    final prevNode = prevStep != null ? graph.nodeById(prevStep.nodeId) : null;
    final isFloorTransition = targetStep.verticalDirection != null ||
        (prevNode != null && prevNode.levelId != targetNode.levelId);

    _simulatedFloor = targetFloor;
    final endP = math.Point<double>(targetNode.x!, targetNode.y!);

    if (isFloorTransition) {
      setState(() {
        _simulatedUserCoords = endP;
      });
      return;
    }

    final startP = _simulatedUserCoords ??
        widget.controller.beaconController.currentCoordinates.value ??
        (targetIndex > 0
            ? () {
                final pNode = graph.nodeById(path[targetIndex - 1].nodeId);
                return (pNode?.x != null && pNode?.y != null)
                    ? math.Point<double>(pNode!.x!, pNode.y!)
                    : endP;
              }()
            : endP);

    _animStartCoords = startP;
    _animEndCoords = endP;
    _walkAnimController?.forward(from: 0.0);
  }

  void _handleManualBypass() {
    final path = widget.controller.currentPath;
    final curIdx = widget.controller.currentStepIndex;
    if (path.isEmpty || curIdx >= path.length) return;

    _animateToTargetNode(curIdx);
    widget.controller.testForceAdvanceStep();
  }

  void _toggleAutoWalk() {
    setState(() {
      _isAutoWalking = !_isAutoWalking;
    });
    if (_isAutoWalking) {
      _advanceAutoWalk();
    } else {
      _walkAnimController?.stop();
    }
  }

  void _advanceAutoWalk() {
    final curIdx = widget.controller.currentStepIndex;
    final path = widget.controller.currentPath;
    if (!_isAutoWalking || path.isEmpty || curIdx >= path.length) {
      setState(() => _isAutoWalking = false);
      return;
    }
    _handleManualBypass();
  }

  void _resetToRealBeacon() {
    setState(() {
      _isAutoWalking = false;
      _walkAnimController?.stop();
      _simulatedUserCoords = null;
      _simulatedFloor = null;
    });
    Get.snackbar(
      'استعادة موقع البيكون',
      'تمت إعادة الموقع للمستشعر الفعلي للبيكون',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.palette.isDark;

    // في حال تفعيل زر "معاينة الإنتاج" يتم إظهار شاشة الإنتاج المعتادة مع زر علوي للعودة
    if (_showProductionPreview) {
      return Stack(
        children: [
          ActiveNavigationScreen(
            controller: widget.controller,
            palette: widget.palette,
          ),
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _showProductionPreview = false),
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'معاينة الإنتاج مفعلة — انقر للعودة لشاشة التشخيص',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Obx(() {
      final beaconController = widget.controller.beaconController;
      final compassController = widget.controller.compassController;
      final graph = widget.controller.navigationRepository.cachedGraph;
      final beaconCoords = beaconController.currentCoordinates.value;
      final effectiveUserCoords = _simulatedUserCoords ??
          beaconCoords ??
          (widget.controller.currentPath.isNotEmpty && graph != null
              ? () {
                  final firstNode = graph.nodeById(widget.controller.currentPath.first.nodeId);
                  return (firstNode?.x != null && firstNode?.y != null)
                      ? math.Point<double>(firstNode!.x!, firstNode.y!)
                      : null;
                }()
              : null);
      final effectiveUserFloor = _simulatedFloor ?? beaconController.currentLocation.value.level;
      final currentHeading = compassController.heading.value;
      final targetHeading = widget.controller.targetStepHeading.value;
      final relativeAngle = widget.controller.currentRelativeAngle.value;
      final deadbandDecision = widget.controller.currentDirection.value;
      final sampleCount = _recorder?.samples.length ?? 0;

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── شريط الترويسة وأدوات الفحص ──────────────────────────────────
            _buildTopBar(isDark, sampleCount),

            const SizedBox(height: 10),

            // ── النافذة الأولى: رسم المسار المتري الحقيقي (Real 2D Canvas) ──
            RouteMetricCanvas(
              graph: graph,
              currentPath: widget.controller.currentPath,
              currentStepIndex: widget.controller.currentStepIndex,
              userCoordinates: effectiveUserCoords,
              currentUserFloor: effectiveUserFloor,
              deviceHeading: currentHeading,
              isDark: isDark,
            ),

            const SizedBox(height: 10),

            // ── النافذة الثانية: مرآة توجيهات الإنتاج (Production Mirror) ───
            _buildProductionMirrorCard(isDark),

            const SizedBox(height: 10),

            // ── النافذة الثالثة: لوحة البوصلة وزوايا التوجيه الحية ───────────
            _buildCompassTelemetryCard(
              isDark,
              currentHeading: currentHeading,
              targetHeading: targetHeading,
              relativeAngle: relativeAngle,
              accuracy: compassController.accuracy.value,
              deadbandDecision: deadbandDecision,
            ),

            const SizedBox(height: 10),

            // ── النافذة الرابعة: تيليميتري التموضع والبلوتوث ────────────────
            _buildPositioningTelemetryCard(isDark, effectiveUserCoords),

            const SizedBox(height: 12),

            // ── النافذة الخامسة: شريط أدوات التحكم الميداني والتصدير ─────────
            _buildFieldActionToolbar(isDark),

            const SizedBox(height: 20),
          ],
        ),
      );
    });
  }

  /// شريط الترويسة وحالة التسجيل
  Widget _buildTopBar(bool isDark, int sampleCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD97706).withAlpha(120),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'TEST',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // مؤشر التسجيل
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withAlpha(30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFEF4444).withAlpha(100)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fiber_manual_record, color: Color(0xFFEF4444), size: 10),
                const SizedBox(width: 4),
                Text(
                  'REC: $sampleCount',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // زر التبديل إلى معاينة الإنتاج
          TextButton.icon(
            onPressed: () => setState(() => _showProductionPreview = true),
            icon: const Icon(Icons.visibility_rounded, size: 14),
            label: const Text(
              'معاينة الإنتاج',
              style: TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  /// مرآة توجيهات الإنتاج: تعرض بدقة ما يراه المستخدم العادي
  Widget _buildProductionMirrorCard(bool isDark) {
    final directionStr = widget.controller.currentDirection.value;
    final instruction = widget.controller.directionInstruction.value;
    final subInstruction = widget.controller.directionSubInstruction.value;
    final remainingDist = widget.controller.remainingDistanceLabel.value;
    final currentStep = widget.controller.currentRouteStep.value;
    final totalSteps = widget.controller.totalRouteSteps.value;
    final isOnPath = widget.controller.isOnCorrectPath.value;
    final offPathCount = widget.controller.consecutiveOffPathReadings;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.navigation_rounded, size: 16, color: Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'مرآة توجيهات الإنتاج',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isOnPath
                      ? const Color(0xFF10B981).withAlpha(30)
                      : const Color(0xFFEF4444).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOnPath ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                child: Text(
                  isOnPath ? 'على المسار' : 'انحراف ($offPathCount/3)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isOnPath ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // السهم المصغر
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D313A) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                ),
                alignment: Alignment.center,
                child: _buildMiniDirectionIcon(directionStr),
              ),
              const SizedBox(width: 12),
              // نصوص التوجيه
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instruction.isEmpty ? 'التوجيه قيد المعالجة...' : instruction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    if (subInstruction.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subInstruction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        Text(
                          'المسافة: $remainingDist',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        Text(
                          'الخطوة: $currentStep / $totalSteps',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// لوحة البوصلة وزوايا التوجيه الحية
  Widget _buildCompassTelemetryCard(
    bool isDark, {
    required double currentHeading,
    required double targetHeading,
    required double relativeAngle,
    required String accuracy,
    required String deadbandDecision,
  }) {
    Color accuracyColor;
    switch (accuracy.toLowerCase()) {
      case 'high':
        accuracyColor = const Color(0xFF10B981);
        break;
      case 'medium':
        accuracyColor = const Color(0xFFF59E0B);
        break;
      case 'low':
        accuracyColor = const Color(0xFFEF4444);
        break;
      default:
        accuracyColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_rounded, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'حالة البوصلة والزوايا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accuracyColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: accuracyColor),
                ),
                child: Text(
                  'دقة: $accuracy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accuracyColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // رسم البوصلة الدائري المصغر
              SizedBox(
                width: 70,
                height: 70,
                child: CustomPaint(
                  painter: _MiniCompassPainter(
                    deviceHeading: currentHeading,
                    targetHeading: targetHeading,
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // مصفوفة القراءات الرقمية المستهلكة مباشرة من الكور
              Expanded(
                child: Column(
                  children: [
                    _buildMetricRow('اتجاه الجهاز:', '${currentHeading.toStringAsFixed(1)}°', isDark),
                    _buildMetricRow('اتجاه المسار:', '${targetHeading.toStringAsFixed(1)}°', isDark),
                    _buildMetricRow('فرق الزاوية:', '${relativeAngle.toStringAsFixed(1)}°', isDark,
                        valueColor: const Color(0xFFD97706)),
                    _buildMetricRow('قرار التردد:', deadbandDecision, isDark,
                        valueColor: const Color(0xFF3B82F6)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// تيليميتري التموضع والبلوتوث
  Widget _buildPositioningTelemetryCard(bool isDark, math.Point<double>? userCoords) {
    final beaconController = widget.controller.beaconController;
    final lockedNode = beaconController.currentLocation.value;
    final rssiMap = beaconController.filteredRssiByUuid;
    double? bestRssi;
    String? bestUuid;
    for (final entry in rssiMap.entries) {
      if (bestRssi == null || entry.value > bestRssi) {
        bestRssi = entry.value;
        bestUuid = entry.key;
      }
    }

    final coordsStr = userCoords != null
        ? 'X: ${userCoords.x.toStringAsFixed(2)}m  |  Y: ${userCoords.y.toStringAsFixed(2)}m'
        : 'قيد التقدير المتري...';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bluetooth_searching_rounded, size: 16, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'بيانات التموضع والبيكونات',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMetricRow('النود المقفول:', '#${lockedNode.nodeID} (${lockedNode.name})', isDark),
          _buildMetricRow('الإحداثيات الحية:', coordsStr, isDark, valueColor: const Color(0xFF8B5CF6)),
          _buildMetricRow('أقوى بيكون:', bestUuid != null ? '${bestUuid.substring(0, math.min(12, bestUuid.length))}...' : '--', isDark),
          _buildMetricRow('قوة الإشارة (RSSI):', bestRssi != null ? '${bestRssi.toStringAsFixed(1)} dBm' : '--', isDark),
        ],
      ),
    );
  }

  /// شريط الأدوات الميداني (أزرار التحكم والتصدير)
  Widget _buildFieldActionToolbar(bool isDark) {
    return Column(
      children: [
        // أزرار التحكم المقيدة للاختبار فقط (تخطي سلس ومحاكاة السير وإعادة التوجيه)
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleManualBypass,
                icon: const Icon(Icons.skip_next_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('تخطي خطوة (سير)', style: TextStyle(fontSize: 11)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _toggleAutoWalk,
                icon: Icon(
                  _isAutoWalking ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  size: 16,
                  color: _isAutoWalking ? Colors.amberAccent : Colors.white,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isAutoWalking ? 'إيقاف السير' : 'محاكاة السير',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAutoWalking ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.controller.testForceReplan();
                  Get.snackbar(
                    'إعادة التوجيه (Replan)',
                    'تم إجبار خوارزمية A* على إعادة حساب المسار من الموقع الحالي',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('إعادة توجيه', style: TextStyle(fontSize: 11)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetToRealBeacon,
                icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('استعادة البيكون', style: TextStyle(fontSize: 11)),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // أزرار التصدير وإنهاء الملاحة
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyTelemetryJson,
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('نسخ تقرير JSON', style: TextStyle(fontSize: 11)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.controller.endNavigation,
                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('إلغاء الملاحة', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _copyTelemetryJson() {
    if (_recorder == null) {
      Get.snackbar('تنبيه', 'خدمة مسجل التيليميتري غير متوفرة حالياً');
      return;
    }

    final jsonStr = _recorder!.exportSessionAsJsonString();
    Clipboard.setData(ClipboardData(text: jsonStr));

    Get.snackbar(
      'تم نسخ تقرير التيليميتري ✅',
      'تم نسخ بيانات الجلسة (${_recorder!.samples.length} عينة) إلى الحافظة بنجاح',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  Widget _buildMetricRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: valueColor ?? (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDirectionIcon(String direction) {
    IconData icon;
    double angle = 0;
    Color color = const Color(0xFFD97706);

    switch (direction) {
      case 'straight':
        icon = Icons.arrow_upward_rounded;
        break;
      case 'slight_right':
        icon = Icons.arrow_upward_rounded;
        angle = 0.39;
        break;
      case 'right':
        icon = Icons.arrow_forward_rounded;
        break;
      case 'slight_left':
        icon = Icons.arrow_upward_rounded;
        angle = -0.39;
        break;
      case 'left':
        icon = Icons.arrow_back_rounded;
        break;
      case 'uturn':
        icon = Icons.u_turn_left_rounded;
        break;
      case 'up':
        icon = Icons.elevator_rounded;
        color = const Color(0xFF3B82F6);
        break;
      case 'down':
        icon = Icons.stairs_rounded;
        color = const Color(0xFF3B82F6);
        break;
      case 'arrived':
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF10B981);
        break;
      default:
        icon = Icons.navigation_rounded;
    }

    Widget result = Icon(icon, size: 30, color: color);
    if (angle != 0) {
      result = Transform.rotate(angle: angle, child: result);
    }
    return result;
  }
}

/// Painter يرسم بوصلة دائرية تعرض زاوية الجهاز وزاوية الهدف
class _MiniCompassPainter extends CustomPainter {
  final double deviceHeading;
  final double targetHeading;
  final bool isDark;

  _MiniCompassPainter({
    required this.deviceHeading,
    required this.targetHeading,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // دائرة البوصلة
    final circlePaint = Paint()
      ..color = isDark ? Colors.white12 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, circlePaint);

    // علامة الشمال (N)
    final northPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy - radius + 5),
      northPaint,
    );

    // مؤشر اتجاه خطوة المسار المطلوبة (Target Bearing)
    final targetRad = (targetHeading - 90) * math.pi / 180.0;
    final targetEnd = Offset(
      center.dx + (radius - 5) * math.cos(targetRad),
      center.dy + (radius - 5) * math.sin(targetRad),
    );
    final targetPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, targetEnd, targetPaint);

    // مؤشر اتجاه الجهاز الفعلي (Device Needle)
    final deviceRad = (deviceHeading - 90) * math.pi / 180.0;
    final deviceEnd = Offset(
      center.dx + (radius - 8) * math.cos(deviceRad),
      center.dy + (radius - 8) * math.sin(deviceRad),
    );
    final devicePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, deviceEnd, devicePaint);

    // النقطة المركزية
    final centerDotPaint = Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.0, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniCompassPainter oldDelegate) {
    return oldDelegate.deviceHeading != deviceHeading ||
        oldDelegate.targetHeading != targetHeading ||
        oldDelegate.isDark != isDark;
  }
}
