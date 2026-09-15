import 'dart:convert';

class HealthUpdate {
  const HealthUpdate({
    required this.nodeIdHex,
    required this.status,
    required this.hopCount,
    required this.lastSeenMs,
  });

  final String nodeIdHex;
  final String status;
  final int hopCount;
  final int lastSeenMs;

  /// بيرجع null لو السطر مش matching للصيغة المتوقعة (سواء كانت JSON أو HEALTH:...).
  static HealthUpdate? tryParse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    // 1. محاولة البارسينج كـ JSON
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final Map<String, dynamic> json = jsonDecode(trimmed);
        if (json['node_id'] != null && json['hop_count'] != null) {
          return HealthUpdate(
            nodeIdHex: json['node_id'].toString(),
            status: json['status']?.toString() ?? 'online',
            hopCount: (json['hop_count'] as num).toInt(),
            lastSeenMs: (json['last_seen_ms'] as num?)?.toInt() ?? 0,
          );
        }
      } catch (_) {
        // ليس JSON صالح
      }
    }

    // 2. محاولة البارسينج كـ صيغة قديمة HEALTH:
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
