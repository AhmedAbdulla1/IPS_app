import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFFFF7643);
const kPrimaryLightColor = Color(0xFFFFECDF);
const kPrimaryGradientColor = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFA53E), Color(0xFFFF7643)],
);
const kSecondaryColor = Color(0xFF3D3A61);
const kTextColor = Color(0xFF3D3A61);

const kAnimationDuration = Duration(milliseconds: 200);

// ---------------------------------------------------------------------------
// Home page palette (Egyptian Parliament wayfinding redesign).
// Kept separate from the palette above so older, not-yet-redesigned pages
// (NavigationPage, SettingsPage, etc.) are unaffected.
// ---------------------------------------------------------------------------
const kHomeBackgroundTop = Color(0xFFFBF3E7);
const kHomeBackgroundBottom = Color(0xFFEEDDBF);
const kGoldColor = Color(0xFFC9A24B);
const kGoldColorLight = Color(0xFFE3C989);
const kDeepBrown = Color(0xFF3B2A1E);
const kCardCream = Color(0xFFFFFDF9);
const kStatusGreen = Color(0xFF3FA35C);
const kStatusAmber = Color(0xFFCF8A2B);

enum LevelNavigation {
  same_level,
  go_up,
  go_down,
  empty,
  reach_destination,
}

enum POIType {
  poi,
  intersection,
  lift,
  entrance,
}

enum MapType {
  onboard,
  view_map,
}

enum CaliType {
  onboard,
  setting,
}
