import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFFFF7643);
const kSecondaryColor = Color(0xFF3D3A61);


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



enum CaliType {
  onboard,
  setting,
}
