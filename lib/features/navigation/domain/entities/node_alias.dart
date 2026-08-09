/// اسم بديل لنقطة معيّنة — بيظهر في نتائج البحث (بالعربي أو الإنجليزي)
class NodeAlias {
  final int nodeId;
  final String text;
  final String lang; // 'ar' | 'en'

  const NodeAlias({
    required this.nodeId,
    required this.text,
    required this.lang,
  });
}
