import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/node_model.dart';
import '../models/level_model.dart';
import '../models/edge_model.dart';
import '../models/vertical_connector_model.dart';
import '../models/destination_model.dart';
import '../../../../core/utils/app_logger.dart';

/// طبقة الوصول الخام لسوبابيز — بترجع Models بس، من غير أي منطق بناء graph
/// (ده شغل الـ repository).
///
/// كاش دائم: كل جدول بيتخزن محليًا (SharedPreferences) كـ JSON خام فور ما
/// يتحمّل بنجاح من الشبكة، وبيفضل متخزّن طول ما التطبيق منزّل (مش بيتمسح
/// لوحده). لو أي طلب شبكة فشل (مفيش نت، تعذّر الوصول لسوبابيز... إلخ)،
/// بيرجع تلقائيًا لآخر نسخة كاش متاحة لنفس الجدول بدل ما يرمي استثناء
/// يوقف الشاشة. لو مفيش كاش خالص لسه (أول تشغيل من غير نت)، الاستثناء
/// الأصلي بيتفرد (rethrow) عشان الطبقة الأعلى (Repository/Controller)
/// تقدر تعرض رسالة واضحة للمستخدم بدل ما التطبيق يقفل فجأة.
class SupabaseNavigationDataSource {
  final SupabaseClient _client;

  static const _cacheKeyPrefix = 'nav_cache_';
  static const _cacheTimestampKey = 'nav_cache_last_synced_at';

  /// بيتحدّث لـ true لو أي جدول رجع من الكاش (مش من الشبكة) في آخر عملية
  /// تحميل. بيتصفّر عن طريق [resetCacheFlag] في بداية كل
  /// `NavigationRepositoryImpl.loadGraph` عشان يعكس حالة آخر محاولة بس.
  bool usedCacheInLastFetch = false;

  SupabaseNavigationDataSource(this._client);

  void resetCacheFlag() {
    usedCacheInLastFetch = false;
  }

  /// آخر وقت اتخزّنت فيه نسخة ناجحة من الشبكة محليًا — null لو لسه مفيش
  /// كاش خالص (أول تشغيل من غير نت أبدًا).
  Future<DateTime?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_cacheTimestampKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<List<T>> _fetchTable<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    try {
      final rows = await _client.from(table).select();
      final list = (rows as List).cast<Map<String, dynamic>>();
      // بنخزن نسخة الكاش في الخلفية من غير ما نستنى — مفيش داعي نأخر
      // الرجوع بالبيانات الحية عشان عملية كتابة محلية.
      unawaited(_saveToCache(table, list));
      return list.map(fromMap).toList();
    } catch (networkError) {
      final cached = await _readFromCache(table);
      if (cached != null) {
        usedCacheInLastFetch = true;
        return cached.map(fromMap).toList();
      }
      rethrow;
    }
  }

  Future<void> _saveToCache(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cacheKeyPrefix$table', jsonEncode(rows));
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // فشل تخزين الكاش (مساحة ممتلئة مثلًا) مش لازم يوقف تدفق البيانات
      // الحية اللي وصلت فعلًا — نتجاهله بأمان.
    }
  }

  Future<List<Map<String, dynamic>>?> _readFromCache(String table) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cacheKeyPrefix$table');
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<List<LevelModel>> fetchLevels() => _fetchTable(
        table: 'levels',
        fromMap: LevelModel.fromMap,
      );

  Future<List<NodeModel>> fetchNodes() => _fetchTable(
        table: 'nodes',
        fromMap: NodeModel.fromMap,
      );

  Future<List<EdgeModel>> fetchEdges() => _fetchTable(
        table: 'edges',
        fromMap: EdgeModel.fromMap,
      );

  Future<List<VerticalConnectorModel>> fetchVerticalConnectors() =>
      _fetchTable(
        table: 'vertical_connectors',
        fromMap: VerticalConnectorModel.fromMap,
      );

  Future<List<ConnectorStopModel>> fetchConnectorStops() => _fetchTable(
        table: 'connector_stops',
        fromMap: ConnectorStopModel.fromMap,
      );

  Future<List<DestinationModel>> fetchDestinations() => _fetchTable(
        table: 'destinations',
        fromMap: DestinationModel.fromMap,
      );

  Future<List<DestinationNodeModel>> fetchDestinationNodes() => _fetchTable(
        table: 'destination_nodes',
        fromMap: DestinationNodeModel.fromMap,
      );

  Future<List<DestinationAliasModel>> fetchDestinationAliases() =>
      _fetchTable(
        table: 'destination_aliases',
        fromMap: DestinationAliasModel.fromMap,
      );

  /// جلب الخريطة بالكامل عبر استدعاء دالة RPC واحدة فائقة السرعة
  Future<Map<String, dynamic>?> fetchBuildingGraphRpc() async {
    try {
      final res = await _client
          .rpc('get_building_graph')
          .timeout(const Duration(seconds: 5));
      if (res != null && res is Map) {
        final map = Map<String, dynamic>.from(res);
        final prefs = await SharedPreferences.getInstance();
        unawaited(prefs.setString('${_cacheKeyPrefix}rpc_graph', jsonEncode(map)));
        unawaited(prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch));
        usedCacheInLastFetch = false;
        return map;
      }
      return null;
    } catch (e) {
      AppLogger.debug('[SupabaseDataSource] RPC get_building_graph failed: $e');
      return null;
    }
  }

  /// قراءة فورية لكاش RPC بدون أي اتصال بالإنترنت (0ms network delay)
  Future<Map<String, dynamic>?> readCachedRpcGraph() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRaw = prefs.getString('${_cacheKeyPrefix}rpc_graph');
    if (cachedRaw != null) {
      usedCacheInLastFetch = true;
      try {
        return Map<String, dynamic>.from(jsonDecode(cachedRaw) as Map);
      } catch (_) {}
    }
    return null;
  }

  /// قراءة جدول معين من الكاش المحلي فقط بدون أي طلب شبكة
  Future<List<T>?> readTableFromCacheOnly<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    final cached = await _readFromCache(table);
    if (cached != null) {
      usedCacheInLastFetch = true;
      return cached.map(fromMap).toList();
    }
    return null;
  }
}
