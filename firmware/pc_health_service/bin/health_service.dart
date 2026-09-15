import 'dart:async';
import 'dart:io';

import 'package:pc_health_service/browser_launcher.dart';
import 'package:pc_health_service/config.dart';
import 'package:pc_health_service/env_loader.dart';
import 'package:pc_health_service/health_protocol.dart';
import 'package:pc_health_service/local_dashboard_server.dart';
import 'package:pc_health_service/node_health_table.dart';
import 'package:pc_health_service/serial_reader.dart';
import 'package:pc_health_service/tcp_reader.dart';

/// نقطة الدخول. بتشتغل: قراءة .env → فتح الاتصال (TCP أو Serial) للـRoot
/// → استقبال أسطر HEALTH:... → تحديث الجدول المحلي → عرضه في نافذة
/// داشبورد محلية (localhost بس - مفيش رفع لأي سيرفر برة الجهاز).
///
/// التشغيل: dart run bin/health_service.dart
Future<void> main() async {
  final env = {...Platform.environment, ...loadEnvFile('.env')};
  final config = HealthServiceConfig.fromEnv(env);

  print('[health_service] 🎯 بدء خدمة مراقبة شبكة Mesh...');
  print('[health_service] الإعدادات:');
  print('  - Connection Mode: ${config.connectionMode}');
  if (config.mockData) {
    print('  - Mock Data: 🧪 مفعلة (اختبار تجريبي)');
  }
  if (config.connectionMode.toLowerCase() == 'serial') {
    print('  - Serial Port: ${config.serialPortName} (${config.baudRate} baud)');
  } else if (config.connectionMode.toLowerCase() == 'mock') {
    print('  - Mode: Mock Simulation');
  } else {
    print('  - Root TCP: ${config.rootHost}:${config.rootPort}');
  }
  print('  - Dashboard: http://127.0.0.1:8787');
  print('  - Upload Interval: ${config.uploadIntervalMs}ms');
  print('  - Timeout Config: base=${config.baseTimeoutMs}ms, per_hop=${config.perHopMarginMs}ms');

  final table = NodeHealthTable(config);

  Stream<String> lineStream;

  if (config.connectionMode.toLowerCase() == 'mock') {
    print('[health_service] 🧪 تشغيل وضع المحاكاة التجريبية (Mock Mode)...');
    final controller = StreamController<String>();
    lineStream = controller.stream;
    Timer.periodic(Duration(seconds: 2), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      controller.add('HEALTH:34851888402484305820348518884024:online:1:$now');
      controller.add('HEALTH:1234567890abcdef1234567890abcdef:online:2:$now');
    });
  } else if (config.connectionMode.toLowerCase() == 'serial') {
    print('[health_service] 🔌 الاتصال عبر Serial Port (${config.serialPortName})...');
    try {
      final serialReader = SerialLineReader(
        portName: config.serialPortName,
        baudRate: config.baudRate,
      );
      lineStream = serialReader.lines();
      print('[health_service] ✅ منفذ Serial مفتوح وبيقرا بيانات...');
    } catch (e) {
      print('\n❌ خطأ أثناء فتح منفذ الـ Serial:');
      print('   $e');
      print('\n💡 نصيحة:');
      print('   1. للعمل عبر شبكة الواي فاي (TCP) بدون الحاجة لمكتبات DLL، اضبط في ملف .env:');
      print('      CONNECTION_MODE=tcp');
      print('      ROOT_HOST=192.168.5.1');
      print('   2. أو للعمل عبر Serial، تأكد من وجود ملف serialport.dll في المجلد الحالي.\n');
      exit(1);
    }
  } else {
    print('[health_service] 🌐 الاتصال عبر TCP Socket (${config.rootHost}:${config.rootPort})...');
    final tcpReader = TcpLineReader(
      host: config.rootHost,
      port: config.rootPort,
    );
    await tcpReader.start();
    lineStream = tcpReader.lines();

    // منتظر اتصال - بيطبع رسالة كل 3 ثواني لو مفيش اتصال
    Timer.periodic(Duration(seconds: 3), (timer) {
      if (!tcpReader.isConnected) {
        print('[health_service] ⏳ في انتظار اتصال بـ Root على ${config.rootHost}:${config.rootPort}...');
      } else {
        timer.cancel();
        print('[health_service] ✅ متصل بـ Root! بيستقبل heartbeats...');
      }
    });

    if (config.mockData) {
      print('[health_service] 🧪 تفعيل إدخال بيانات تجريبية وهمية (Mock Data Active)...');
      Timer.periodic(Duration(seconds: 2), (_) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final mock1 = HealthUpdate.tryParse('HEALTH:34851888402484305820348518884024:online:1:$now');
        final mock2 = HealthUpdate.tryParse('HEALTH:1234567890abcdef1234567890abcdef:online:2:$now');
        if (mock1 != null) table.applyUpdate(mock1);
        if (mock2 != null) table.applyUpdate(mock2);
      });
    }
  }

  // استقبال الأسطر وتحديث الجدول المحلي أول بأول
  lineStream.listen((line) {
    final update = HealthUpdate.tryParse(line);
    if (update == null) {
      // سطر مش من بروتوكول الـhealth (ممكن يكون log عادي من الفيرموير)
      if (line.isNotEmpty) {
        print('[log] $line');
      }
      return;
    }
    
    // تحديث الجدول بـ heartbeat جديد
    table.applyUpdate(update);
    print('[update] Node: ${update.nodeIdHex.substring(0, 8)}... level=${update.hopCount}');
  });

  // الداشبورد المحلي - بيتعرض في نافذة مستقلة (--app)، مفيش أي رفع
  // لـSupabase أو أي سيرفر بره الجهاز (قرار معماري 2026-09-12، راجع
  // MESH_PROGRESS.md). لو محتاج ترجع رفع سحابي تاني في المستقبل،
  // lib/supabase_uploader.dart لسه موجود ومحفوظ للرجوع له.
  print('[health_service] 🚀 بيفتح Dashboard...');
  final dashboard = LocalDashboardServer(table, config);
  final dashboardUrl = await dashboard.start();
  await openAsAppWindow(dashboardUrl);

  // بيفضل شغال - مفيش exit condition، ده long-running service
  print('[health_service] ✅ خدمة شغالة. Ctrl+C للإيقاف.');
  
  // منع خروج البرنامج
  await stdin.drain();
}
