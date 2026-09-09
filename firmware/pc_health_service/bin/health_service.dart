import 'dart:async';
import 'dart:io';

import 'package:pc_health_service/config.dart';
import 'package:pc_health_service/env_loader.dart';
import 'package:pc_health_service/health_protocol.dart';
import 'package:pc_health_service/node_health_table.dart';
import 'package:pc_health_service/serial_reader.dart';
import 'package:pc_health_service/supabase_uploader.dart';

/// نقطة الدخول. بتشتغل: قراءة .env → فتح الـSerial → استقبال أسطر
/// HEALTH:... → تحديث الجدول المحلي → رفع batch دوري لـSupabase.
///
/// التشغيل: dart run bin/health_service.dart
Future<void> main() async {
  final env = {...Platform.environment, ...loadEnvFile('.env')};
  final config = HealthServiceConfig.fromEnv(env);

  if (config.supabaseServiceKey.isEmpty) {
    stderr.writeln(
      '[health_service] تحذير: SUPABASE_SERVICE_KEY فاضي في .env - '
      'الرفع لـSupabase هيفشل. راجع .env.example.',
    );
  }

  print('[health_service] بيفتح الـSerial على ${config.serialPortName} '
      '(${config.baudRate} baud)...');

  final table = NodeHealthTable(config);
  final uploader = SupabaseHealthUploader(config);

  late final SerialLineReader reader;
  try {
    reader = SerialLineReader(
      portName: config.serialPortName,
      baudRate: config.baudRate,
    );
  } catch (e) {
    stderr.writeln('[health_service] فشل فتح الـSerial: $e');
    stderr.writeln(
      '[health_service] المنافذ المتاحة: '
      // TODO: اطبع SerialPort.availablePorts هنا لو الفتح فشل، عشان
      // يبان بسهولة إيه المنفذ الصح بدل ما نلف يدوي.
      '(راجع Device Manager أو SerialPort.availablePorts)',
    );
    exit(1);
  }

  // استقبال الأسطر وتحديث الجدول المحلي أول بأول.
  reader.lines().listen((line) {
    final update = HealthUpdate.tryParse(line);
    if (update == null) {
      // سطر مش من بروتوكول الـhealth (ممكن يكون log عادي من الفيرموير)
      // - بنطبعه للمراقبة بس مش بنعالجه.
      print('[serial] $line');
      return;
    }
    table.applyUpdate(update);
  });

  // رفع دوري batch لـSupabase - مش على كل رسالة.
  Timer.periodic(Duration(milliseconds: config.uploadIntervalMs), (_) async {
    final records = table.allRecords;
    if (records.isEmpty) return;

    await uploader.uploadBatch(records);
    print(
      '[health_service] رفع ${records.length} node '
      '(${table.onlineRecords.length} online, '
      '${table.offlineRecords.length} offline)',
    );
  });

  // بيفضل شغال - مفيش exit condition، ده long-running service.
  print('[health_service] شغال. Ctrl+C للإيقاف.');
}
