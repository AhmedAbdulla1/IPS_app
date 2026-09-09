import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'node_health_table.dart';

/// برفع batch لجدول node_health في Supabase عبر PostgREST upsert.
/// شوف migration الجدول المقترح في MESH_DESIGN.md §7.
class SupabaseHealthUploader {
  SupabaseHealthUploader(this.config);

  final HealthServiceConfig config;

  Future<void> uploadBatch(List<NodeHealthRecord> records) async {
    if (records.isEmpty) return;

    final uri = Uri.parse('${config.supabaseUrl}/rest/v1/node_health');

    final body = records
        .map((r) => {
              'node_esp32_uuid': r.nodeIdHex,
              'status': r.isOnline(config) ? 'online' : 'offline',
              'hop_count': r.hopCount,
              'last_seen_at': r.lastMessageAt.toUtc().toIso8601String(),
            })
        .toList();

    final response = await http.post(
      uri,
      headers: {
        'apikey': config.supabaseServiceKey,
        'Authorization': 'Bearer ${config.supabaseServiceKey}',
        'Content-Type': 'application/json',
        // upsert بدل insert عادي - لو الـnode موجودة بالفعل بتتحدث.
        'Prefer': 'resolution=merge-duplicates',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // TODO: استبدال print بـlogger حقيقي + retry logic لو الرفع فشل
      // (مثلاً الإنترنت مقطوع مؤقتًا - محتاجين نراكم البيانات مش نرميها).
      print(
        '[SupabaseHealthUploader] فشل الرفع (${response.statusCode}): '
        '${response.body}',
      );
    }
  }
}
