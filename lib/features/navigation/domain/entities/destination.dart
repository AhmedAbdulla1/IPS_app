/// وجهة قابلة للبحث — منفصلة عن العقدة الفيزيائية (NavNode).
///
/// السبب: عقدة واحدة (بيكون واحد) ممكن تمثّل أكتر من مكان منطقي (زي حمام +
/// مكتب في نفس النقطة)، والعكس: أكتر من عقدة ممكن تمثّل نفس المكان فعليًا
/// (زي مدخل كبير بيغطيه بيكونين). البحث لازم يشتغل على "أماكن منطقية" مش
/// على عدد البيكونات.
class Destination {
  final int id;
  final String nameAr;
  final String? nameEn;

  /// العقدة/العقد اللي الوجهة دي بتتربط بيها. أول عنصر بيُستخدم كهدف
  /// افتراضي لحساب المسار (routing target).
  final List<int> nodeIds;

  final List<String> aliasesAr;
  final List<String> aliasesEn;

  /// نوع الاختصار السريع اللي الوجهة دي بتقدر تتحل ليه (زي 'elevator',
  /// 'restroom_male', 'restroom_female') — null لو مش مرتبطة بأي اختصار.
  /// بيُستخدم لاختيار "أقرب" وجهة مطابقة تلقائيًا لما المستخدم يدوس على
  /// زرار اختصار سريع (فيه أكتر من أسانسير/حمام في المبنى عادةً).
  final String? shortcutType;

  const Destination({
    required this.id,
    required this.nameAr,
    this.nameEn,
    required this.nodeIds,
    this.aliasesAr = const [],
    this.aliasesEn = const [],
    this.shortcutType,
  });

  /// العقدة المستخدمة فعليًا كهدف توجيه.
  int get primaryNodeId => nodeIds.first;
}
