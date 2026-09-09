import 'config.dart';
import 'health_protocol.dart';

/// حالة node واحدة زي ما محفوظة في الجدول المحلي (in-memory).
class NodeHealthRecord {
  NodeHealthRecord({
    required this.nodeIdHex,
    required this.hopCount,
    required this.lastMessageAt,
  });

  final String nodeIdHex;
  int hopCount;
  DateTime lastMessageAt;

  /// الحالة الفعلية بتتحسب ديناميكيًا بناءً على dynamic timeout، مش
  /// بتتخزن كـflag ثابت - كده لو الخدمة اتوقفت وشغلناها تاني، الحالة
  /// بتترجع تتحسب صح من أول رسالة توصل.
  bool isOnline(HealthServiceConfig config) {
    final timeout = config.timeoutForHopCount(hopCount);
    final elapsed = DateTime.now().difference(lastMessageAt).inMilliseconds;
    return elapsed <= timeout;
  }
}

/// الجدول المحلي لحالة كل النودز. بيتحدث من HealthUpdate واصلة عبر
/// الـSerial، وبيتقرا وقت الرفع لـSupabase.
///
/// ملحوظة مهمة (موثقة في MESH_DESIGN.md §7): "Offline" هنا معناها
/// "مفيش heartbeat وصل في الوقت المتوقع"، مش بالضرورة إن النود نفسها
/// معطوبة - خصوصًا لو نودز تانية بعدها في نفس الفرع.
class NodeHealthTable {
  NodeHealthTable(this.config);

  final HealthServiceConfig config;
  final Map<String, NodeHealthRecord> _records = {};

  void applyUpdate(HealthUpdate update) {
    final existing = _records[update.nodeIdHex];
    if (existing != null) {
      existing.hopCount = update.hopCount;
      existing.lastMessageAt = DateTime.now();
    } else {
      _records[update.nodeIdHex] = NodeHealthRecord(
        nodeIdHex: update.nodeIdHex,
        hopCount: update.hopCount,
        lastMessageAt: DateTime.now(),
      );
    }
  }

  List<NodeHealthRecord> get allRecords => _records.values.toList();

  List<NodeHealthRecord> get onlineRecords =>
      _records.values.where((r) => r.isOnline(config)).toList();

  List<NodeHealthRecord> get offlineRecords =>
      _records.values.where((r) => !r.isOnline(config)).toList();
}
