import 'package:flutter/painting.dart';

import '../world/scenery.dart';

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
    this.scenery = SceneryStyle.none,
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

  /// What grows on this course, if anything.
  ///
  /// Mars gets [SceneryStyle.none] and means it: bare ground is what makes
  /// it read as Mars. A green course without scenery is not a green course,
  /// it is the same course tinted green.
  final SceneryStyle scenery;
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
  scenery: marsSurveyScenery,
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
  scenery: marsStormScenery,
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
  scenery: marsPolarScenery,
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

/// A temperate valley - somewhere that is not Mars at all. Grass, pines
/// and a high pale sky.
///
/// Every theme below still obeys the atmospheric-perspective rule: the
/// bands step lighter as they recede, and every one of them is lighter
/// than [groundFill], so distance reads as distance.
const LevelTheme meadowVale = LevelTheme(
  name: 'Meadow',
  skyTop: Color(0xFFBFDCE8),
  skyMid: Color(0xFFDDEBDC),
  skyLow: Color(0xFFF0F5DF),
  skyHorizon: Color(0xFFFAFBEA),
  mountainFar: Color(0xFFCBE0B7),
  mountainMid: Color(0xFFA9CF92),
  mountainNear: Color(0xFF87BE74),
  groundFill: Color(0xFF5E9E4E),
  groundFillDeep: Color(0xFF2A4526),
  groundCrust: Color(0xFF9AD463),
  sun: Color(0xFFFFFDEC),
  starOpacity: 0.0,
  hazeOpacity: 0.18,
  scenery: meadowScenery,
);

/// High alpine, mid-afternoon. Cold blue light, snowfields, and enough
/// haze on the peaks that the far ridges almost vanish.
const LevelTheme alpineSnow = LevelTheme(
  name: 'Snowfield',
  skyTop: Color(0xFF5E7FC4),
  skyMid: Color(0xFF9DB6E2),
  skyLow: Color(0xFFCFDDF2),
  skyHorizon: Color(0xFFEFF4FC),
  mountainFar: Color(0xFFE4ECF7),
  mountainMid: Color(0xFFC7D6EA),
  mountainNear: Color(0xFFA8BCD8),
  groundFill: Color(0xFFF2F7FD),
  groundFillDeep: Color(0xFF8FA6C4),
  groundCrust: Color(0xFFFFFFFF),
  sun: Color(0xFFFFFFFF),
  starOpacity: 0.0,
  hazeOpacity: 0.36,
  scenery: snowScenery,
);

/// A refinery yard under a smog ceiling. Sodium light on the underside of
/// the murk, oil-stained ground, nothing growing.
const LevelTheme refineryYard = LevelTheme(
  name: 'Refinery',
  skyTop: Color(0xFF3F4432),
  skyMid: Color(0xFF7C7A50),
  skyLow: Color(0xFFBCAC66),
  skyHorizon: Color(0xFFDCC87C),
  mountainFar: Color(0xFFC0B487),
  mountainMid: Color(0xFF9A9068),
  mountainNear: Color(0xFF746E50),
  groundFill: Color(0xFF44402F),
  groundFillDeep: Color(0xFF1C1A13),
  groundCrust: Color(0xFFB29A4A),
  sun: Color(0xFFE8D48A),
  starOpacity: 0.0,
  hazeOpacity: 0.55,
  scenery: industrialScenery,
);

/// Moorland under a full moon. Almost monochrome, with a cold green cast
/// on everything the moon touches.
const LevelTheme moonlitMoor = LevelTheme(
  name: 'Moonlit moor',
  skyTop: Color(0xFF0B1024),
  skyMid: Color(0xFF16213F),
  skyLow: Color(0xFF2C3A5C),
  skyHorizon: Color(0xFF4E6B7A),
  mountainFar: Color(0xFF4C6472),
  mountainMid: Color(0xFF3A4E5C),
  mountainNear: Color(0xFF2B3A46),
  groundFill: Color(0xFF1E2E32),
  groundFillDeep: Color(0xFF0A1216),
  groundCrust: Color(0xFF5FA894),
  sun: Color(0xFFF2F8FF),
  starOpacity: 1.0,
  hazeOpacity: 0.26,
  scenery: hauntedScenery,
);

/// A floodlit stadium at night: banked stands going back into the dark,
/// and a clay track that reads hot under the lights.
const LevelTheme floodlitArena = LevelTheme(
  name: 'Arena',
  skyTop: Color(0xFF10131E),
  skyMid: Color(0xFF1B2133),
  skyLow: Color(0xFF2E3550),
  skyHorizon: Color(0xFF4A5570),
  mountainFar: Color(0xFF6B7690),
  mountainMid: Color(0xFF515B74),
  mountainNear: Color(0xFF3B4459),
  groundFill: Color(0xFF8C2A2A),
  groundFillDeep: Color(0xFF3A0F0F),
  groundCrust: Color(0xFFE8B36A),
  sun: Color(0xFFFFFFFF),
  starOpacity: 0.25,
  hazeOpacity: 0.20,
  scenery: arenaScenery,
);

/// Late-afternoon desert. Sandstone mesas stepping back into the heat
/// haze, ochre sand, hard light.
const LevelTheme sunbakedMesa = LevelTheme(
  name: 'Mesa',
  skyTop: Color(0xFF7FB6D9),
  skyMid: Color(0xFFBBD5E2),
  skyLow: Color(0xFFF0DCB4),
  skyHorizon: Color(0xFFFAE9C4),
  mountainFar: Color(0xFFE7C79C),
  mountainMid: Color(0xFFD2A473),
  mountainNear: Color(0xFFB87F52),
  groundFill: Color(0xFFB5794A),
  groundFillDeep: Color(0xFF5E3520),
  groundCrust: Color(0xFFEFC078),
  sun: Color(0xFFFFF6D8),
  starOpacity: 0.0,
  hazeOpacity: 0.40,
  scenery: desertScenery,
);

/// A tropical shore late in the day. Pale sand, green shallows stepping
/// out to a hazy horizon, palms leaning off the dune.
const LevelTheme sunsetCay = LevelTheme(
  name: 'Cay',
  skyTop: Color(0xFF4FA7D8),
  skyMid: Color(0xFF9FD3E4),
  skyLow: Color(0xFFDCEFE4),
  skyHorizon: Color(0xFFF6F0D2),
  mountainFar: Color(0xFFCFE9DF),
  mountainMid: Color(0xFF9AD4CB),
  mountainNear: Color(0xFF6EBBB4),
  groundFill: Color(0xFFE0C78E),
  groundFillDeep: Color(0xFF8A6A44),
  groundCrust: Color(0xFFF7E7BC),
  sun: Color(0xFFFFF8DC),
  starOpacity: 0.0,
  hazeOpacity: 0.30,
  scenery: beachScenery,
);
