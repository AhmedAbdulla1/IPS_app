/// بيتترمي لو مفيش مسار ممكن بين نقطتين في الـ graph (مثلاً لو الداتا
/// ناقصة أو النقطتين مش متصلين أصلًا).
class PathNotFoundException implements Exception {
  final String message;
  const PathNotFoundException(this.message);

  @override
  String toString() => 'PathNotFoundException: $message';
}
