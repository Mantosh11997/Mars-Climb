import 'upgrades.dart';

/// Everything the game remembers about you between sessions.
///
/// Deliberately plain data with no Flutter and no storage in it: the store
/// reads and writes it, the screens read it, and it can be built by hand in
/// a test without touching a device.
class PlayerProfile {
  const PlayerProfile({
    this.coins = 0,
    this.ownedVehicles = const {'rover'},
    this.completedLevels = const {},
    this.bestDistance = const {},
    this.upgrades = const {},
    this.lastVehicleId,
    this.soundOn = true,
  });

  /// A fresh player: the starter machine, no money, nothing cleared.
  static const PlayerProfile fresh = PlayerProfile();

  final int coins;

  /// Vehicle ids that have been bought. The starter is always in here -
  /// see [normalised], which is what the store guarantees on load.
  final Set<String> ownedVehicles;

  /// Level numbers that have been finished at least once. This is what
  /// gates the next course, so it must survive a reinstall or the campaign
  /// silently reopens from the top.
  final Set<int> completedLevels;

  /// Furthest metres reached on each level number, whether or not it was
  /// finished. Shown on the course cards.
  final Map<int, double> bestDistance;

  /// Fitted parts, per vehicle id. Absent means nothing fitted.
  final Map<String, Upgrades> upgrades;

  /// The machine last taken out. Lets the home screen's PLAY button pick up
  /// where you left off instead of dumping you back at the top of the
  /// carousel every time.
  final String? lastVehicleId;

  /// Whether the game makes any noise. On by default - a game that boots
  /// silent reads as broken rather than as considerate.
  final bool soundOn;

  Upgrades upgradesFor(String vehicleId) =>
      upgrades[vehicleId] ?? Upgrades.none;

  bool owns(String vehicleId) => ownedVehicles.contains(vehicleId);

  bool hasCompleted(int levelNumber) => completedLevels.contains(levelNumber);

  /// Whether a course is open.
  ///
  /// The first is always open; every other one wants the previous course
  /// finished. That is the whole campaign gate, in one place, so the
  /// selection screen and any test agree on it by construction.
  bool canPlay(int levelNumber) =>
      levelNumber <= 1 || hasCompleted(levelNumber - 1);

  double bestOn(int levelNumber) => bestDistance[levelNumber] ?? 0;

  // --- what the home screen shows -------------------------------------

  int get clearedCount => completedLevels.length;

  int get ownedCount => ownedVehicles.length;

  /// Every course's furthest run, added up. A single number for "how much
  /// of this game have I actually driven".
  double get totalDistance =>
      bestDistance.values.fold(0.0, (sum, d) => sum + d);

  /// The first course not yet cleared - where PLAY should send you.
  ///
  /// Scans from the bottom rather than taking the highest cleared plus one,
  /// so a gap (cleared 1 and 3, failed 2) sends you back to 2 rather than
  /// past it.
  int nextLevelNumber(int courseCount) {
    for (var n = 1; n <= courseCount; n++) {
      if (!hasCompleted(n)) return n;
    }
    return courseCount; // everything cleared: sit on the last one
  }

  bool get hasFinishedCampaign => completedLevels.isNotEmpty;

  PlayerProfile copyWith({
    int? coins,
    Set<String>? ownedVehicles,
    Set<int>? completedLevels,
    Map<int, double>? bestDistance,
    Map<String, Upgrades>? upgrades,
    String? lastVehicleId,
    bool? soundOn,
  }) =>
      PlayerProfile(
        coins: coins ?? this.coins,
        ownedVehicles: ownedVehicles ?? this.ownedVehicles,
        completedLevels: completedLevels ?? this.completedLevels,
        bestDistance: bestDistance ?? this.bestDistance,
        upgrades: upgrades ?? this.upgrades,
        lastVehicleId: lastVehicleId ?? this.lastVehicleId,
        soundOn: soundOn ?? this.soundOn,
      );

  PlayerProfile withCoins(int delta) =>
      copyWith(coins: (coins + delta).clamp(0, 1 << 40));

  PlayerProfile withVehicle(String id) =>
      copyWith(ownedVehicles: {...ownedVehicles, id});

  PlayerProfile withUpgrades(String vehicleId, Upgrades fitted) =>
      copyWith(upgrades: {...upgrades, vehicleId: fitted});

  PlayerProfile withLastVehicle(String id) => copyWith(lastVehicleId: id);

  PlayerProfile withSound(bool on) => copyWith(soundOn: on);

  /// Record the outcome of a run. Distance only ever moves up.
  PlayerProfile withRun({
    required int levelNumber,
    required double distance,
    required bool finished,
  }) =>
      copyWith(
        completedLevels:
            finished ? {...completedLevels, levelNumber} : completedLevels,
        bestDistance: {
          ...bestDistance,
          levelNumber:
              distance > bestOn(levelNumber) ? distance : bestOn(levelNumber),
        },
      );

  /// The starter machine can never be missing: a profile without it leaves
  /// the player with nothing to drive and no way to earn the money to fix
  /// that. Applied on load, so even a corrupted save recovers.
  PlayerProfile normalised({required String starterVehicleId}) =>
      owns(starterVehicleId) ? this : withVehicle(starterVehicleId);

  Map<String, dynamic> toJson() => {
        'coins': coins,
        'owned': ownedVehicles.toList()..sort(),
        'completed': completedLevels.toList()..sort(),
        'best': bestDistance.map((k, v) => MapEntry('$k', v)),
        'upgrades': upgrades.map((k, v) => MapEntry(k, v.toJson())),
        if (lastVehicleId != null) 'lastVehicle': lastVehicleId,
        'sound': soundOn,
      };

  /// Rebuild a profile from a decoded save.
  ///
  /// Every field is read defensively and independently. A save is JSON on a
  /// device we do not control, and a single wrong-typed value should cost
  /// you that one field - not your coins, your machines and your campaign
  /// along with it. Anything unreadable falls back to the fresh default.
  static PlayerProfile fromJson(Map<String, dynamic> json) => PlayerProfile(
        coins: (_num(json['coins'])?.toInt() ?? 0).clamp(0, 1 << 40),
        ownedVehicles: {
          for (final id in _list(json['owned'])) '$id',
        },
        completedLevels: {
          for (final n in _list(json['completed']))
            if (_num(n) case final v?) v.toInt(),
        },
        bestDistance: {
          for (final e in _map(json['best']).entries)
            if (int.tryParse('${e.key}') case final n?)
              n: _num(e.value)?.toDouble() ?? 0,
        },
        lastVehicleId:
            json['lastVehicle'] is String ? json['lastVehicle'] as String : null,
        // Absent means on: a save written before sound existed should come
        // back with sound, not silently muted.
        soundOn: json['sound'] is bool ? json['sound'] as bool : true,
        upgrades: {
          for (final e in _map(json['upgrades']).entries)
            if (e.value is Map)
              '${e.key}': Upgrades.fromJson(
                Map<String, dynamic>.from(e.value as Map),
              ),
        },
      );

  static num? _num(Object? v) => v is num ? v : null;
  static List<Object?> _list(Object? v) => v is List ? v : const [];
  static Map<Object?, Object?> _map(Object? v) => v is Map ? v : const {};
}
