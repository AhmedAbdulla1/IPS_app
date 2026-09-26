/// تحويل رقم الدور لصيغة عربية ("الدور الأول"، "الدور الثاني"...)
/// بيغطي أول 10 أدوار الشائعة، وبيرجع رقم عادي لو الدور أكبر.
String floorOrdinalArabic(int floor) {
  const ordinals = {
    0: 'الأرضي',
    1: 'الأول',
    2: 'الثاني',
    3: 'الثالث',
    4: 'الرابع',
    5: 'الخامس',
    6: 'السادس',
    7: 'السابع',
    8: 'الثامن',
    9: 'التاسع',
    10: 'العاشر',
  };
  final ordinal = ordinals[floor];
  return ordinal != null ? 'الدور $ordinal' : 'الدور $floor';
}

/// تحويل رقم الدور لصيغة إنجليزية ("Ground Floor", "First Floor"...)
String floorOrdinalEnglish(int floor) {
  const ordinals = {
    0: 'Ground Floor',
    1: 'First Floor',
    2: 'Second Floor',
    3: 'Third Floor',
    4: 'Fourth Floor',
    5: 'Fifth Floor',
    6: 'Sixth Floor',
    7: 'Seventh Floor',
    8: 'Eighth Floor',
    9: 'Ninth Floor',
    10: 'Tenth Floor',
  };
  final ordinal = ordinals[floor];
  return ordinal ?? 'Floor $floor';
}
