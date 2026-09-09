/// إعدادات الخدمة. القيم الحساسة (Supabase URL/Key) بتتحمّل من ملف
/// `.env` مش بتتكتب هنا مباشرة - شوف `.env.example`.
library;

class HealthServiceConfig {
  HealthServiceConfig({
    required this.serialPortName,
    required this.baudRate,
    required this.supabaseUrl,
    required this.supabaseServiceKey,
    required this.uploadIntervalMs,
    required this.baseTimeoutMs,
    required this.perHopMarginMs,
  });

  /// اسم منفذ الـSerial بتاع الـRoot (مثال: "COM5" على ويندوز).
  /// TODO: يتحدد فعليًا وقت التوصيل - ممكن نضيف auto-detect لاحقًا
  /// (يدور على أول منفذ بيبعت سطر يبدأ بـ"HEALTH:" أو "[RESET REASON]").
  final String serialPortName;

  final int baudRate;

  final String supabaseUrl;
  final String supabaseServiceKey;

  /// كل قد إيه نرفع batch لـSupabase (مش على كل رسالة heartbeat).
  final int uploadIntervalMs;

  /// نفس صيغة الـtimeout الديناميكي الموثقة في MESH_DESIGN.md:
  /// node_timeout_ms = base + hop_count * per_hop_margin
  final int baseTimeoutMs;
  final int perHopMarginMs;

  int timeoutForHopCount(int hopCount) =>
      baseTimeoutMs + (hopCount * perHopMarginMs);

  /// بيحمّل الإعدادات من متغيرات البيئة (اتحملت مسبقًا من .env في main).
  factory HealthServiceConfig.fromEnv(Map<String, String> env) {
    return HealthServiceConfig(
      serialPortName: env['SERIAL_PORT'] ?? 'COM5',
      baudRate: int.tryParse(env['BAUD_RATE'] ?? '') ?? 115200,
      supabaseUrl: env['SUPABASE_URL'] ?? '',
      supabaseServiceKey: env['SUPABASE_SERVICE_KEY'] ?? '',
      uploadIntervalMs:
          int.tryParse(env['UPLOAD_INTERVAL_MS'] ?? '') ?? 5000,
      baseTimeoutMs: int.tryParse(env['BASE_TIMEOUT_MS'] ?? '') ?? 3000,
      perHopMarginMs: int.tryParse(env['PER_HOP_MARGIN_MS'] ?? '') ?? 800,
    );
  }
}
