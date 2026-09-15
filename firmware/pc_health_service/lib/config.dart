/// إعدادات الخدمة. القيم الحساسة (Supabase URL/Key) بتتحمّل من ملف
/// `.env` مش بتتكتب هنا مباشرة - شوف `.env.example`.
library;

class HealthServiceConfig {
  HealthServiceConfig({
    required this.connectionMode,
    required this.rootHost,
    required this.rootPort,
    required this.mockData,
    required this.serialPortName,
    required this.baudRate,
    required this.supabaseUrl,
    required this.supabaseServiceKey,
    required this.uploadIntervalMs,
    required this.baseTimeoutMs,
    required this.perHopMarginMs,
  });

  /// طريقة الاتصال: 'tcp' لشبكة الـWi-Fi أو 'serial' لكابل الـUSB
  final String connectionMode;

  /// عنوان الـ IP الخاص بـ ESP32 Root (مثلاً "192.168.5.1" عند الاتصال بشبكته)
  final String rootHost;

  /// منفذ الـ TCP الخاص بـ Root (الافتراضي 9998)
  final int rootPort;

  /// تفعيل وضع البيانات التجريبية للاختبار بدون بورد حقيقية
  final bool mockData;

  /// اسم منفذ الـSerial بتاعة الـRoot (مثال: "COM4" على ويندوز).
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
      connectionMode: env['CONNECTION_MODE'] ?? 'tcp',
      rootHost: env['ROOT_HOST'] ?? '192.168.5.1',
      rootPort: int.tryParse(env['ROOT_PORT'] ?? '') ?? 9998,
      mockData: env['MOCK_DATA']?.toLowerCase() == 'true',
      serialPortName: env['SERIAL_PORT'] ?? 'COM4',
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
