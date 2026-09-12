import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'node_health_table.dart';

/// سيرفر HTTP محلي بسيط بيعرض حالة النودز في نافذة (مش تاب متصفح
/// عادي - بيتفتح بـ`--app=` عشان يبان كأنه تطبيق مستقل من غير شريط
/// عنوان/تابات). بيشتغل على localhost بس، مفيش أي اتصال بره الجهاز.
///
/// المسارات:
///   GET /            → صفحة الداشبورد (HTML مُضمّن في الكود نفسه)
///   GET /api/health  → JSON بحالة كل النودز الحالية
class LocalDashboardServer {
  LocalDashboardServer(this.table, this.config, {this.port = 8787});

  final NodeHealthTable table;
  final HealthServiceConfig config;
  final int port;

  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print('[dashboard] شغال على http://127.0.0.1:$port');
    _serve();
    return Uri.parse('http://127.0.0.1:$port');
  }

  Future<void> _serve() async {
    await for (final request in _server!) {
      try {
        if (request.uri.path == '/api/health') {
          _handleHealthApi(request);
        } else {
          _handleIndex(request);
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('error: $e');
        await request.response.close();
      }
    }
  }

  void _handleHealthApi(HttpRequest request) {
    final now = DateTime.now();
    final records = table.allRecords
      ..sort((a, b) => a.nodeIdHex.compareTo(b.nodeIdHex));

    final json = {
      'now': now.toIso8601String(),
      'nodes': records
          .map((r) => {
                'node_id_hex': r.nodeIdHex,
                'hop_count': r.hopCount,
                'last_message_at': r.lastMessageAt.toIso8601String(),
                'online': r.isOnline(config),
                'timeout_ms': config.timeoutForHopCount(r.hopCount),
              })
          .toList(),
    };

    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(json));
    request.response.close();
  }

  void _handleIndex(HttpRequest request) {
    request.response
      ..headers.contentType = ContentType.html
      ..write(_dashboardHtml);
    request.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }
}

/// صفحة الداشبورد - HTML/CSS/JS مُضمّنة هنا عشان الحزمة تفضل Dart CLI
/// بسيطة من غير الحاجة لـasset bundling. بتعمل fetch لـ/api/health كل
/// ثانية وتحدّث الجدول.
const String _dashboardHtml = r'''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<title>حالة شبكة IPS Mesh</title>
<style>
  :root {
    --bg: #0f1220; --card: #1a1e33; --accent: #4f8cff;
    --ok: #34c77b; --bad: #ff5c5c; --text: #e8eaf6; --muted: #9aa0c3;
    --border: #2a2f4a;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; font-family: "Segoe UI", Tahoma, Arial, sans-serif;
    background: var(--bg); color: var(--text); padding: 20px;
  }
  h1 { font-size: 18px; margin: 0 0 4px 0; }
  .subtitle { color: var(--muted); font-size: 12px; margin-bottom: 16px; }
  .summary { display: flex; gap: 12px; margin-bottom: 16px; }
  .pill {
    padding: 6px 14px; border-radius: 999px; font-size: 13px; font-weight: 600;
  }
  .pill.total { background: #2a2f4a; }
  .pill.online { background: var(--ok); color: #06210f; }
  .pill.offline { background: var(--bad); color: #2a0606; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th, td { border: 1px solid var(--border); padding: 8px 10px; text-align: center; }
  th { background: var(--card); color: var(--muted); position: sticky; top: 0; }
  tr.offline { background: rgba(255,92,92,0.08); }
  .status-dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-left: 6px; }
  .status-dot.on { background: var(--ok); }
  .status-dot.off { background: var(--bad); }
  .uid { font-family: Consolas, monospace; font-size: 11px; direction: ltr; }
  .empty { color: var(--muted); text-align: center; padding: 40px; }
  .updated-at { color: var(--muted); font-size: 11px; margin-top: 10px; }
</style>
</head>
<body>
  <h1>🕸️ حالة شبكة IPS Mesh</h1>
  <div class="subtitle">تحديث تلقائي كل ثانية - بيانات محلية بس (مش متخزنة أو مرفوعة لأي مكان)</div>

  <div class="summary">
    <span class="pill total" id="pillTotal">0 نود</span>
    <span class="pill online" id="pillOnline">0 online</span>
    <span class="pill offline" id="pillOffline">0 offline</span>
  </div>

  <table>
    <thead>
      <tr>
        <th>الحالة</th>
        <th>Node UUID</th>
        <th>Hop Count</th>
        <th>آخر ظهور</th>
        <th>Timeout المحسوب</th>
      </tr>
    </thead>
    <tbody id="rows">
      <tr><td colspan="5" class="empty">في انتظار أول heartbeat...</td></tr>
    </tbody>
  </table>

  <div class="updated-at" id="updatedAt"></div>

<script>
async function refresh() {
  try {
    const res = await fetch('/api/health');
    const data = await res.json();
    render(data);
  } catch (e) {
    document.getElementById('updatedAt').textContent = 'فشل الاتصال بالسيرفر المحلي: ' + e.message;
  }
}

function render(data) {
  const rows = document.getElementById('rows');
  const nodes = data.nodes || [];

  if (nodes.length === 0) {
    rows.innerHTML = '<tr><td colspan="5" class="empty">في انتظار أول heartbeat...</td></tr>';
  } else {
    rows.innerHTML = nodes.map(n => {
      const lastSeen = new Date(n.last_message_at);
      const secondsAgo = Math.max(0, Math.round((new Date(data.now) - lastSeen) / 1000));
      return `
        <tr class="${n.online ? '' : 'offline'}">
          <td><span class="status-dot ${n.online ? 'on' : 'off'}"></span>${n.online ? 'Online' : 'Offline'}</td>
          <td class="uid">${n.node_id_hex}</td>
          <td>${n.hop_count}</td>
          <td>من ${secondsAgo} ثانية</td>
          <td>${(n.timeout_ms / 1000).toFixed(1)} ثانية</td>
        </tr>`;
    }).join('');
  }

  const online = nodes.filter(n => n.online).length;
  document.getElementById('pillTotal').textContent = nodes.length + ' نود';
  document.getElementById('pillOnline').textContent = online + ' online';
  document.getElementById('pillOffline').textContent = (nodes.length - online) + ' offline';
  document.getElementById('updatedAt').textContent = 'آخر تحديث: ' + new Date(data.now).toLocaleTimeString('ar-EG');
}

refresh();
setInterval(refresh, 1000);
</script>
</body>
</html>
''';
