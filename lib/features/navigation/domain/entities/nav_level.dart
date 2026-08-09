/// دور من أدوار المبنى (كيان Domain نقي)
class NavLevel {
  final String id;
  final String nameAr;
  final String? nameEn;
  final int order;

  const NavLevel({
    required this.id,
    required this.nameAr,
    this.nameEn,
    required this.order,
  });
}
