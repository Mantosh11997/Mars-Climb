import 'package:flutter/painting.dart';

/// The look of one course.
///
/// Sky, distant scenery and ground are all per level, so two courses never
/// read as the same place with different bumps.
///
/// The one rule that must hold: **atmospheric perspective**. Each mountain
/// band steps lighter and hazier as it recedes, and every band stays
/// lighter than [groundFill]. Get that backwards and distant scenery reads
/// as a hole in the world rather than as something behind the terrain.
class LevelTheme {
  const LevelTheme({
    required this.name,
    required this.skyTop,
    required this.skyMid,
    required this.skyLow,
    required this.skyHorizon,
    required this.mountainFar,
    required this.mountainMid,
    required this.mountainNear,
    required this.groundFill,
    required this.groundFillDeep,
    required this.groundCrust,
    required this.sun,
    required this.starOpacity,
    required this.hazeOpacity,
  });

  final String name;

  final Color skyTop;
  final Color skyMid;
  final Color skyLow;
  final Color skyHorizon;

  final Color mountainFar;
  final Color mountainMid;
  final Color mountainNear;

  final Color groundFill;
  final Color groundFillDeep;
  final Color groundCrust;

  final Color sun;

  /// 0 hides the stars entirely - use it for a daylight course.
  final double starOpacity;

  /// Strength of the dust band sitting on the horizon.
  final double hazeOpacity;
}

/// Dusk over the northern plains. Warm, familiar, the tutorial look.
const LevelTheme duskPlains = LevelTheme(
  name: 'Dusk',
  skyTop: Color(0xFF2B1A2E),
  skyMid: Color(0xFF8A3B2A),
  skyLow: Color(0xFFD4703C),
  skyHorizon: Color(0xFFE9A063),
  mountainFar: Color(0xFFD08965),
  mountainMid: Color(0xFFBE6E4A),
  mountainNear: Color(0xFFA85735),
  groundFill: Color(0xFF8F3D22),
  groundFillDeep: Color(0xFF43190F),
  groundCrust: Color(0xFFD8703A),
  sun: Color(0xFFFFE2B0),
  starOpacity: 0.6,
  hazeOpacity: 0.30,
);

/// Harsh white noon. Washed out, high and bright, no stars.
const LevelTheme noonBasin = LevelTheme(
  name: 'Noon',
  skyTop: Color(0xFF6C7EA8),
  skyMid: Color(0xFFA98D89),
  skyLow: Color(0xFFD8A277),
  skyHorizon: Color(0xFFF0C79A),
  mountainFar: Color(0xFFE0AE87),
  mountainMid: Color(0xFFCE9169),
  mountainNear: Color(0xFFB8734A),
  groundFill: Color(0xFF9E5730),
  groundFillDeep: Color(0xFF542916),
  groundCrust: Color(0xFFF0A462),
  sun: Color(0xFFFFFDF2),
  starOpacity: 0.0,
  hazeOpacity: 0.42,
);

/// A dust storm rolling in. Ochre, close, oppressive.
const LevelTheme dustStorm = LevelTheme(
  name: 'Dust storm',
  skyTop: Color(0xFF4A2E16),
  skyMid: Color(0xFF8A5520),
  skyLow: Color(0xFFC08A38),
  skyHorizon: Color(0xFFD9A855),
  mountainFar: Color(0xFFC79E62),
  mountainMid: Color(0xFFB2854D),
  mountainNear: Color(0xFF97673A),
  groundFill: Color(0xFF7A4A24),
  groundFillDeep: Color(0xFF3A2010),
  groundCrust: Color(0xFFCE9448),
  sun: Color(0xFFFFE9B8),
  starOpacity: 0.0,
  hazeOpacity: 0.62,
);

/// Deep night on the volcano. Cold, blue, stars everywhere.
const LevelTheme polarNight = LevelTheme(
  name: 'Night',
  skyTop: Color(0xFF090C1E),
  skyMid: Color(0xFF1B2246),
  skyLow: Color(0xFF3A3A63),
  skyHorizon: Color(0xFF6E5470),
  mountainFar: Color(0xFF6E5C7E),
  mountainMid: Color(0xFF574863),
  mountainNear: Color(0xFF41354C),
  groundFill: Color(0xFF33253A),
  groundFillDeep: Color(0xFF140E1B),
  groundCrust: Color(0xFF8C6E9E),
  sun: Color(0xFFDCE6FF),
  starOpacity: 1.0,
  hazeOpacity: 0.22,
);

/// Sunrise over the ice cap. Pink and pale, cold light.
const LevelTheme frostDawn = LevelTheme(
  name: 'Frost dawn',
  skyTop: Color(0xFF2A2444),
  skyMid: Color(0xFF6B4A6A),
  skyLow: Color(0xFFC2778A),
  skyHorizon: Color(0xFFF2B49E),
  mountainFar: Color(0xFFE4B5AE),
  mountainMid: Color(0xFFC7908F),
  mountainNear: Color(0xFFA46D74),
  groundFill: Color(0xFF7E4F52),
  groundFillDeep: Color(0xFF32191F),
  groundCrust: Color(0xFFEBA88F),
  sun: Color(0xFFFFF0E0),
  starOpacity: 0.45,
  hazeOpacity: 0.34,
);
