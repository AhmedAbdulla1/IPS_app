import 'dart:math' as math;

/// حساب اتجاه المشي (heading بالدرجات، 0-360) من نقطة لجارتها بناءً على
/// إحداثيات x,y — بدل ما يتحط يدوي في الداتا (زي ما كان في الداتا الوهمية
/// القديمة).
///
/// المعادلة اتستنتجت بمطابقة الداتا الوهمية القديمة (schema بيها heading
/// يدوي لكل جار) مع فروق الإحداثيات المقابلة لها، عشان نضمن إن الاتجاهات
/// الجديدة متوافقة مع نفس المنطق اللي الـ UI (سهم الاتجاه/البوصلة) اتبني عليه:
///
///   heading = (atan2(dy, -dx) بالدرجات + 360) % 360
///   حيث dx = xB - xA , dy = yB - yA
///
/// اتحقق منها على 4 حالات من الداتا القديمة:
///   dx=-5, dy=0  → 0°    |  dx=5, dy=0  → 180°
///   dx=0, dy=-5  → 270°  |  dx=0, dy=5  → 90°
double calculateHeading({
  required double xA,
  required double yA,
  required double xB,
  required double yB,
}) {
  final dx = xB - xA;
  final dy = yB - yA;
  final degrees = math.atan2(dy, -dx) * 180 / math.pi;
  return (degrees + 360) % 360;
}
