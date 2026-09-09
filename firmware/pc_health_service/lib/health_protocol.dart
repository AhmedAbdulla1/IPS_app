/// بارسر بروتوكول HEALTH:... الموثق في MESH_DESIGN.md §6.
///
/// الصيغة: HEALTH:<node_id_hex>:<status>:<hop_count>:<last_seen_ms>
/// مثال:   HEALTH:0000000000000000000000000000c8:online:3:128340
library;

class HealthUpdate {
  const HealthUpdate({
    required this.nodeIdHex,
    required this.status,
    required this.hopCount,
    required this.lastSeenMs,
  });

  final String nodeIdHex;

  /// "online" أو "offline" - القيمة اللي بعتها الـRoot نفسه وقت الرسالة.
  /// ملحوظة: الحالة النهائية المعروضة في الداشبورد بتتحسب محليًا هنا
  /// (NodeHealthTable) بناءً على dynamic timeout، مش بس بالقيمة دي.
  final String status;

  final int hopCount;
  final int lastSeenMs;

  /// بيرجع null لو السطر مش matching للصيغة المتوقعة (بيتجاهل بهدوء -
  /// ممكن يكون سطر تاني زي [RESET REASON] أو رسايل تصحيح أخطاء عادية).
  static HealthUpdate? tryParse(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('HEALTH:')) return null;

    final parts = trimmed.substring('HEALTH:'.length).split(':');
    if (parts.length != 4) return null;

    final hopCount = int.tryParse(parts[2]);
    final lastSeenMs = int.tryParse(parts[3]);
    if (hopCount == null || lastSeenMs == null) return null;

    return HealthUpdate(
      nodeIdHex: parts[0],
      status: parts[1],
      hopCount: hopCount,
      lastSeenMs: lastSeenMs,
    );
  }
}
