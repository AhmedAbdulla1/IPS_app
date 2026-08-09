import '../../domain/entities/nav_level.dart';

class LevelModel {
  final String levelId;
  final String nameAr;
  final String? nameEn;
  final int levelOrder;

  const LevelModel({
    required this.levelId,
    required this.nameAr,
    this.nameEn,
    required this.levelOrder,
  });

  factory LevelModel.fromMap(Map<String, dynamic> map) {
    return LevelModel(
      levelId: map['level_id'] as String,
      nameAr: map['name_ar'] as String,
      nameEn: map['name_en'] as String?,
      levelOrder: map['level_order'] as int,
    );
  }

  NavLevel toEntity() {
    return NavLevel(
      id: levelId,
      nameAr: nameAr,
      nameEn: nameEn,
      order: levelOrder,
    );
  }
}
