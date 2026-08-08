import '../models/navigation_destination.dart';

/// أدوات بحث ذكي على بيانات ستاتيك بالعربي:
/// - تطبيع الحروف (أ/إ/آ -> ا, ة -> ه, ى -> ي...) عشان الكتابة المختلفة تلاقي نفس النتيجة
/// - بحث في الاسم الأساسي + المرادفات (aliases)
/// - ترتيب النتائج حسب الأولوية (تطابق كامل > يبدأ بيه > يحتويه > تشابه تقريبي)
class ArabicSearchUtils {
  ArabicSearchUtils._();

  /// تطبيع نص عربي لتسهيل المطابقة
  static String normalize(String input) {
    var s = input.trim().toLowerCase();
    // إزالة التشكيل والتطويل
    s = s.replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '');
    // توحيد الألف بأشكالها
    s = s.replaceAll(RegExp(r'[إأآٱ]'), 'ا');
    // توحيد الياء/الألف المقصورة
    s = s.replaceAll('ى', 'ي');
    // توحيد التاء المربوطة بالهاء
    s = s.replaceAll('ة', 'ه');
    // توحيد الهمزات على الواو/الياء
    s = s.replaceAll('ؤ', 'و');
    s = s.replaceAll('ئ', 'ي');
    return s;
  }

  /// مسافة Levenshtein بسيطة — لتحمّل خطأ إملائي أو حرفين زيادة/ناقص
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final List<List<int>> d = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) d[i][0] = i;
    for (var j = 0; j <= b.length; j++) d[0][j] = j;

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((v, e) => v < e ? v : e);
      }
    }
    return d[a.length][b.length];
  }

  /// حساب درجة تطابق نص واحد (اسم أو مرادف) مع نص البحث.
  /// كل ما الرقم أعلى، كل ما التطابق أقوى. -1 يعني مفيش تطابق خالص.
  static int _scoreField(String field, String query) {
    final normField = normalize(field);
    final normQuery = normalize(query);

    if (normQuery.isEmpty) return 0;
    if (normField == normQuery) return 100;
    if (normField.startsWith(normQuery)) return 80;
    if (normField.contains(normQuery)) return 60;

    // مطابقة تقريبية لكل كلمة في الحقل (يسمح بغلطة إملائية بسيطة)
    final words = normField.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.isEmpty) continue;
      final distance = _levenshtein(word, normQuery);
      final maxAllowed = normQuery.length <= 3 ? 1 : 2;
      if (distance <= maxAllowed) return 40 - distance * 5;
    }
    return -1;
  }

  /// بحث ذكي في قائمة الوجهات، بيرجع النتائج مرتبة حسب الأقوى تطابقًا.
  static List<BuildingDestination> search(
    List<BuildingDestination> source,
    String query,
  ) {
    if (query.trim().isEmpty) return source;

    final scored = <MapEntry<BuildingDestination, int>>[];

    for (final destination in source) {
      var bestScore = _scoreField(destination.name, query);

      for (final alias in destination.aliases) {
        final aliasScore = _scoreField(alias, query);
        // مطابقة المرادف مهمة بس أقل أولوية شوية من الاسم الأساسي نفسه
        final adjusted = aliasScore >= 0 ? aliasScore - 5 : -1;
        if (adjusted > bestScore) bestScore = adjusted;
      }

      if (bestScore >= 0) {
        scored.add(MapEntry(destination, bestScore));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }
}
