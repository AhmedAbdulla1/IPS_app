import os

target_path = r"D:\IPS_app\ips_tester\lib\main.dart"

content = '''import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// إعدادات Supabase المأخوذة من تطبيق IPS الرئيسي
const String supabaseUrl = 'https://dqnmxlljqiqgqmntzvcx.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxbm14bGxqcWlxZ3FtbnR6dmN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNjQwMzIsImV4cCI6MjEwMTg0MDAzMn0.RBcHQxjlZy3Cv-57gaRwM_BISoYaFJfTfJs9kxTLT7w';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const IpsTesterApp());
}

class IpsTesterApp extends StatelessWidget {
  const IpsTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPS Beacon Inspector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const BeaconInspectorScreen(),
    );
  }
}

// ── نماذج بيانات مبسطة بدون تعقيد ─────────────────────────────
class NodeItem {
  final int id;
  final String levelId;
  final String nameAr;
  final String nameEn;
  final String type;
  final String? facilityType;
  final String? esp32Uuid;
  final double? x;
  final double? y;

  NodeItem({
    required this.id,
    required this.levelId,
    required this.nameAr,
    required this.nameEn,
    required this.type,
    this.facilityType,
    this.esp32Uuid,
    this.x,
    this.y,
  });

  factory NodeItem.fromMap(Map<String, dynamic> map) {
    return NodeItem(
      id: map['node_id'] as int,
      levelId: map['level_id']?.toString() ?? '',
      nameAr: map['name_ar']?.toString() ?? 'بدون اسم',
      nameEn: map['name_en']?.toString() ?? '',
      type: map['type']?.toString() ?? 'poi',
      facilityType: map['facility_type']?.toString(),
      esp32Uuid: map['esp32_uuid']?.toString(),
      x: (map['x'] != null) ? (map['x'] as num).toDouble() : null,
      y: (map['y'] != null) ? (map['y'] as num).toDouble() : null,
    );
  }
}

class EdgeItem {
  final int id;
  final int nodeA;
  final int nodeB;
  final double? distance;
  final String? kind;

  EdgeItem({
    required this.id,
    required this.nodeA,
    required this.nodeB,
    this.distance,
    this.kind,
  });

  factory EdgeItem.fromMap(Map<String, dynamic> map) {
    return EdgeItem(
      id: map['edge_id'] as int,
      nodeA: map['node_id_a'] as int,
      nodeB: map['node_id_b'] as int,
      distance: (map['distance_meters'] != null) ? (map['distance_meters'] as num).toDouble() : null,
      kind: map['kind']?.toString(),
    );
  }
}

class DetectedBeacon {
  final String uuid;
  final String cleanUuid;
  final int rssi;
  final double distance;
  final String macAddress;
  final DateTime lastSeen;

  DetectedBeacon({
    required this.uuid,
    required this.cleanUuid,
    required this.rssi,
    required this.distance,
    required this.macAddress,
    required this.lastSeen,
  });
}

// ── شاشة الفاحص الرئيسية ─────────────────────────────────────
class BeaconInspectorScreen extends StatefulWidget {
  const BeaconInspectorScreen({super.key});

  @override
  State<BeaconInspectorScreen> createState() => _BeaconInspectorScreenState();
}

class _BeaconInspectorScreenState extends State<BeaconInspectorScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<BleStatus>? _bleStatusSubscription;

  bool _isDbLoading = true;
  String _dbStatus = 'جاري الاتصال بـ Supabase...';

  // الخرائط لتسريع البحث
  final Map<int, NodeItem> _nodesById = {};
  final Map<String, NodeItem> _nodesByCleanUuid = {};
  final List<EdgeItem> _edges = [];

  // البيكونات الملتقطة حالياً
  final Map<String, DetectedBeacon> _activeBeacons = {};
  DetectedBeacon? _closestBeacon;
  NodeItem? _closestNode;

  bool _isScanning = false;
  String _scanStatus = 'في الانتظار';
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _loadDatabaseData();
    _listenToBleStatus();
    _requestPermissionsAndStartScan();

    // تايمر لمسح البيكونات التي انقطعت إشارتها بعد 6 ثوانٍ
    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final now = DateTime.now();
      bool changed = false;
      _activeBeacons.removeWhere((key, beacon) {
        final isOld = now.difference(beacon.lastSeen).inSeconds > 6;
        if (isOld) changed = true;
        return isOld;
      });
      if (changed) {
        _recalculateClosestBeacon();
      }
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _bleStatusSubscription?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }

  void _listenToBleStatus() {
    _bleStatusSubscription = _ble.statusStream.listen((status) {
      if (status == BleStatus.ready) {
        if (!_isScanning) {
          _startBleScan();
        }
      } else if (status == BleStatus.poweredOff) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _scanStatus = '⚠️ البلوتوث مغلق، يرجى تفعيله على الهاتف';
          });
        }
      }
    });
  }

  String _cleanUuid(String? uuid) {
    if (uuid == null) return '';
    return uuid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  }

  // 1. تحميل النودز والـ Edges من Supabase
  Future<void> _loadDatabaseData() async {
    setState(() {
      _isDbLoading = true;
      _dbStatus = 'جاري جلب النقاط والمسارات...';
    });

    try {
      final client = Supabase.instance.client;

      // جلب النودز
      final nodesRes = await client.from('nodes').select();
      _nodesById.clear();
      _nodesByCleanUuid.clear();

      for (final row in nodesRes) {
        final node = NodeItem.fromMap(row);
        _nodesById[node.id] = node;
        if (node.esp32Uuid != null && node.esp32Uuid!.isNotEmpty) {
          final clean = _cleanUuid(node.esp32Uuid);
          _nodesByCleanUuid[clean] = node;
        }
      }

      // جلب المسارات Edges
      final edgesRes = await client.from('edges').select();
      _edges.clear();
      for (final row in edgesRes) {
        _edges.add(EdgeItem.fromMap(row));
      }

      setState(() {
        _isDbLoading = false;
        _dbStatus = 'تم تحميل ${_nodesById.length} نقطة و ${_edges.length} مسار بنجاح';
      });
      _recalculateClosestBeacon();
    } catch (e) {
      setState(() {
        _isDbLoading = false;
        _dbStatus = 'خطأ في قاعدة البيانات: $e';
      });
    }
  }

  // 2. طلب صلاحيات البلوتوث والموقع ثم تشغيل السكان
  Future<void> _requestPermissionsAndStartScan() async {
    setState(() => _scanStatus = 'جاري فحص الصلاحيات...');

    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    bool granted = statuses[Permission.location]?.isGranted == true ||
        statuses[Permission.bluetoothScan]?.isGranted == true;

    if (!granted) {
      setState(() => _scanStatus = 'يرجى منح صلاحيات البلوتوث والموقع');
      return;
    }

    _startBleScan();
  }

  // 3. مسح البيكونات عبر البلوتوث
  void _startBleScan() {
    _scanSubscription?.cancel();
    setState(() {
      _isScanning = true;
      _scanStatus = 'جاري البحث عن البيكونات عبر البلوتوث...';
    });

    _scanSubscription = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      final beacon = _parseBeacon(device);
      if (beacon != null) {
        _activeBeacons[beacon.cleanUuid] = beacon;
        _recalculateClosestBeacon();
      }
    }, onError: (err) {
      setState(() {
        _isScanning = false;
        if (err.toString().contains('Bluetooth disabled')) {
          _scanStatus = '⚠️ البلوتوث مغلق، يرجى تفعيله على الهاتف';
        } else {
          _scanStatus = 'خطأ أثناء المسح: $err';
        }
      });
    });
  }

  // 4. استخراج بيانات الـ iBeacon والـ Custom IPS Protocol
  DetectedBeacon? _parseBeacon(DiscoveredDevice device) {
    final bytes = device.manufacturerData;
    if (bytes.isEmpty) return null;

    String? rawUuidHex;
    int txPower = -59;

    // A. بروتوكول TRANEX IPS المخصص (0xFFFF)
    if (bytes.length >= 26 && bytes[0] == 0xFF && bytes[1] == 0xFF) {
      final uuidBytes = bytes.sublist(2, 18);
      rawUuidHex = uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      txPower = -59;
    }
    // B. معيار Apple iBeacon القياسي (0x4C 0x00 0x02 0x15)
    else if (bytes.length >= 23) {
      int offset = -1;
      for (int i = 0; i <= bytes.length - 23; i++) {
        if (i + 24 <= bytes.length &&
            bytes[i] == 0x4C &&
            bytes[i + 1] == 0x00 &&
            bytes[i + 2] == 0x02 &&
            bytes[i + 3] == 0x15) {
          offset = i + 4;
          break;
        } else if (bytes[i] == 0x02 && bytes[i + 1] == 0x15) {
          offset = i + 2;
          break;
        }
      }

      if (offset != -1 && bytes.length >= offset + 21) {
        final uuidBytes = bytes.sublist(offset, offset + 16);
        rawUuidHex = uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        txPower = bytes[offset + 20].toSigned(8);
      }
    }

    if (rawUuidHex == null || rawUuidHex.length != 32) return null;

    final formattedUuid =
        '${rawUuidHex.substring(0, 8)}-${rawUuidHex.substring(8, 12)}-${rawUuidHex.substring(12, 16)}-${rawUuidHex.substring(16, 20)}-${rawUuidHex.substring(20, 32)}'
            .toLowerCase();

    final clean = rawUuidHex.toLowerCase();
    final dist = _calculateDistance(txPower, device.rssi);

    return DetectedBeacon(
      uuid: formattedUuid,
      cleanUuid: clean,
      rssi: device.rssi,
      distance: dist,
      macAddress: device.id,
      lastSeen: DateTime.now(),
    );
  }

  double _calculateDistance(int txPower, int rssi) {
    if (rssi == 0) return -1.0;
    final ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return math.pow(ratio, 10).toDouble();
    } else {
      return (0.89976) * math.pow(ratio, 7.7095) + 0.111;
    }
  }

  // 5. حساب أقرب بيكون (أعلى إشارة RSSI = النقطة التي تحتها المستخدم)
  void _recalculateClosestBeacon() {
    if (_activeBeacons.isEmpty) {
      if (mounted) {
        setState(() {
          _closestBeacon = null;
          _closestNode = null;
        });
      }
      return;
    }

    // ترتيب البيكونات حسب قوة الإشارة RSSI تنازلياً (-40 أقوى من -80)
    final sorted = _activeBeacons.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    final best = sorted.first;
    final node = _nodesByCleanUuid[best.cleanUuid];

    if (mounted) {
      setState(() {
        _closestBeacon = best;
        _closestNode = node;
      });
    }
  }

  // جلب كل المسارات المرتبطة بالنقطة الحالية
  List<Map<String, dynamic>> _getConnectedNodes(int nodeId) {
    final List<Map<String, dynamic>> connections = [];

    for (final edge in _edges) {
      int? targetId;
      if (edge.nodeA == nodeId) {
        targetId = edge.nodeB;
      } else if (edge.nodeB == nodeId) {
        targetId = edge.nodeA;
      }

      if (targetId != null) {
        final targetNode = _nodesById[targetId];
        connections.add({
          'targetId': targetId,
          'node': targetNode,
          'distance': edge.distance,
          'kind': edge.kind,
        });
      }
    }

    return connections;
  }

  @override
  Widget build(BuildContext context) {
    final connections = _closestNode != null ? _getConnectedNodes(_closestNode!.id) : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('IPS Beacon Inspector', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات من السيرفر',
            onPressed: _loadDatabaseData,
          ),
          IconButton(
            icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled),
            color: _isScanning ? const Color(0xFF38BDF8) : Colors.orangeAccent,
            tooltip: 'إعادة تشغيل فحص البلوتوث',
            onPressed: _requestPermissionsAndStartScan,
          ),
        ],
      ),
      body: _isDbLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_dbStatus, style: const TextStyle(fontSize: 16)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDatabaseData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // شريط الحالة
                  _buildStatusBar(),
                  const SizedBox(height: 16),

                  // كارت النقطة التي أنت تحتها الآن
                  _buildCurrentNodeCard(),
                  const SizedBox(height: 16),

                  // كارت النقاط المرتبطة بها
                  if (_closestNode != null) ...[
                    _buildConnectedNodesCard(connections),
                    const SizedBox(height: 16),
                  ],

                  // كارت باقي البيكونات في النطاق
                  _buildAllDetectedBeaconsCard(),
                ],
              ),
            ),
    );
  }

  // ── الويدجتس ──────────────────────────────────────────────
  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isScanning ? Colors.greenAccent : Colors.amberAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scanStatus,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _dbStatus,
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_activeBeacons.length} بيكون',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentNodeCard() {
    if (_closestBeacon == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const Column(
          children: [
            Icon(Icons.radar, size: 48, color: Colors.white30),
            SizedBox(height: 12),
            Text(
              'لا يوجد بيكون ملتقط حالياً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'تأكد من تشغيل البلوتوث والاقتراب من بوردات الـ ESP32',
              style: TextStyle(fontSize: 13, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final b = _closestBeacon!;
    final n = _closestNode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'أنت تحت هذه النقطة الآن',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const Spacer(),
              Text(
                '${b.rssi} dBm',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // رقم النقطة واسمها
          if (n != null) ...[
            Text(
              'نقطة رقم #${n.id}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 4),
            Text(
              n.nameAr,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (n.nameEn.isNotEmpty && n.nameEn != n.nameAr)
              Text(
                n.nameEn,
                style: const TextStyle(fontSize: 15, color: Colors.white60),
              ),
            const Divider(color: Colors.white12, height: 24),

            // تفاصيل النقطة في شبكة الإحداثيات
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildInfoBadge('الدور', n.levelId, Icons.layers),
                _buildInfoBadge('النوع', n.type, Icons.category),
                if (n.facilityType != null)
                  _buildInfoBadge('المرفق', n.facilityType!, Icons.room_preferences),
                if (n.x != null && n.y != null)
                  _buildInfoBadge('الإحداثيات', '(${n.x}, ${n.y})', Icons.place),
                _buildInfoBadge('المسافة التقديرية', '${b.distance.toStringAsFixed(1)} متر', Icons.straighten),
              ],
            ),
          ] else ...[
            const Text(
              'بيكون غير مسجل في Supabase!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 6),
            const Text(
              'الـ UUID الملتقط لا يطابق أي نقطة معرفة في قاعدة البيانات.',
              style: TextStyle(color: Colors.white70),
            ),
          ],

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UUID: ${b.uuid}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70)),
                const SizedBox(height: 2),
                Text('MAC: ${b.macAddress}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedNodesCard(List<Map<String, dynamic>> connections) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, color: Color(0xFF38BDF8), size: 22),
              const SizedBox(width: 8),
              Text(
                'النقاط المرتبطة بها (${connections.length} مسار)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (connections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لا توجد مسارات مسجلة في جدول edges لهذه النقطة.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ...connections.map((c) {
              final targetId = c['targetId'] as int;
              final NodeItem? target = c['node'] as NodeItem?;
              final double? dist = c['distance'] as double?;
              final String? kind = c['kind'] as String?;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$targetId',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            target?.nameAr ?? 'نقطة #$targetId',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'الدور: ${target?.levelId ?? "—"} | النوع: ${target?.type ?? "—"}',
                            style: const TextStyle(fontSize: 12, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (dist != null)
                          Text(
                            '${dist.toStringAsFixed(1)}م',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent),
                          ),
                        if (kind != null)
                          Text(
                            kind,
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAllDetectedBeaconsCard() {
    final sorted = _activeBeacons.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_tethering, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'جميع البيكونات في النطاق (${sorted.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const Text('لم يتم رصد أي بيكون بعد.', style: TextStyle(color: Colors.white54))
          else
            ...sorted.map((b) {
              final node = _nodesByCleanUuid[b.cleanUuid];
              final isCurrent = _closestBeacon?.cleanUuid == b.cleanUuid;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFF38BDF8).withValues(alpha: 0.1) : Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent ? const Color(0xFF38BDF8) : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      node != null ? '#${node.id}' : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: node != null ? const Color(0xFF38BDF8) : Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node?.nameAr ?? 'غير مسجل (${b.macAddress})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            b.uuid,
                            style: const TextStyle(fontSize: 10, color: Colors.white38, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${b.rssi} dBm',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: b.rssi > -70 ? Colors.greenAccent : Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF38BDF8)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
'''

os.makedirs(os.path.dirname(target_path), exist_ok=True)
with open(target_path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Successfully generated {target_path} ({len(content)} bytes)")
