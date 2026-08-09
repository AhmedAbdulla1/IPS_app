import '../entities/building_graph.dart';

/// عقد (contract) الوصول لبيانات الملاحة — الـ domain layer بيعرف بس الشكل
/// ده، ومش عارف حاجة عن Supabase أو أي مصدر بيانات تاني.
abstract class NavigationRepository {
  /// بيجيب الـ graph كامل من المصدر (Supabase) ويبنيه في الميموري.
  /// لو [forceRefresh] false وفيه نسخة متخزّنة، بيرجّعها من غير ما يعمل
  /// طلب شبكة جديد.
  Future<BuildingGraph> loadGraph({bool forceRefresh = false});

  /// آخر نسخة متحمّلة من الـ graph — null لو لسه ماتحمّلش.
  /// مفيد للأماكن اللي محتاجة وصول متزامن (sync) للـ graph بعد ما يتحمّل
  /// مرة في بداية التطبيق (زي بدء التنقل).
  BuildingGraph? get cachedGraph;
}
