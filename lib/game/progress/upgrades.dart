/// What you can spend money on, and what it does to a machine.
///
/// Four parts, five levels each. The numbers below are the whole balance
/// of the upgrade economy, so they live together where they can be read
/// against one another rather than scattered through the UI.
enum UpgradePart { engine, grip, suspension, tank }

extension UpgradePartInfo on UpgradePart {
  String get label => switch (this) {
        UpgradePart.engine => 'ENGINE',
        UpgradePart.grip => 'GRIP',
        UpgradePart.suspension => 'SUSPENSION',
        UpgradePart.tank => 'FUEL TANK',
      };

  /// What the player is actually buying, in one line.
  String get blurb => switch (this) {
        UpgradePart.engine => 'More pull, and a higher ceiling before it '
            'runs out of revs.',
        UpgradePart.grip => 'Tyre bite. The single biggest thing between '
            'you and a steep face.',
        UpgradePart.suspension => 'Softer springs, better damped. Lands '
            'heavy jumps without spitting you off.',
        UpgradePart.tank => 'A bigger cell. Longer before the run ends on '
            'its own.',
      };
}

/// How far each part can be taken.
const int maxUpgradeLevel = 5;

/// One machine's fitted parts.
class Upgrades {
  const Upgrades({
    this.engine = 0,
    this.grip = 0,
    this.suspension = 0,
    this.tank = 0,
  });

  static const Upgrades none = Upgrades();

  final int engine;
  final int grip;
  final int suspension;
  final int tank;

  int levelOf(UpgradePart part) => switch (part) {
        UpgradePart.engine => engine,
        UpgradePart.grip => grip,
        UpgradePart.suspension => suspension,
        UpgradePart.tank => tank,
      };

  Upgrades withPart(UpgradePart part, int level) => Upgrades(
        engine: part == UpgradePart.engine ? level : engine,
        grip: part == UpgradePart.grip ? level : grip,
        suspension: part == UpgradePart.suspension ? level : suspension,
        tank: part == UpgradePart.tank ? level : tank,
      );

  /// One step on [part], clamped at the top.
  Upgrades bumped(UpgradePart part) =>
      withPart(part, (levelOf(part) + 1).clamp(0, maxUpgradeLevel));

  bool isMaxed(UpgradePart part) => levelOf(part) >= maxUpgradeLevel;

  int get total => engine + grip + suspension + tank;

  /// 0 when nothing is fitted, 1 when everything is.
  double get fraction => total / (maxUpgradeLevel * UpgradePart.values.length);

  Map<String, dynamic> toJson() => {
        'engine': engine,
        'grip': grip,
        'suspension': suspension,
        'tank': tank,
      };

  static Upgrades fromJson(Map<String, dynamic> json) {
    // Same contract as PlayerProfile.fromJson: a wrong-typed field costs
    // that field, not the whole machine's fitted parts.
    int read(String key) {
      final v = json[key];
      return (v is num ? v.toInt() : 0).clamp(0, maxUpgradeLevel);
    }

    return Upgrades(
      engine: read('engine'),
      grip: read('grip'),
      suspension: read('suspension'),
      tank: read('tank'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Upgrades &&
      other.engine == engine &&
      other.grip == grip &&
      other.suspension == suspension &&
      other.tank == tank;

  @override
  int get hashCode => Object.hash(engine, grip, suspension, tank);
}

/// What the next level of [part] costs, given what is already fitted.
///
/// Rises linearly, so the last level of a part costs five times the first
/// and a fully-built machine is a real investment rather than a formality.
/// Returns null when the part is already at its ceiling.
int? upgradeCost(UpgradePart part, int currentLevel) {
  if (currentLevel >= maxUpgradeLevel) return null;
  const base = {
    UpgradePart.engine: 140,
    UpgradePart.grip: 120,
    UpgradePart.suspension: 110,
    UpgradePart.tank: 90,
  };
  return base[part]! * (currentLevel + 1);
}

/// Everything still unbought on a machine, in coins.
int remainingUpgradeCost(Upgrades fitted) {
  var total = 0;
  for (final part in UpgradePart.values) {
    for (var lvl = fitted.levelOf(part); lvl < maxUpgradeLevel; lvl++) {
      total += upgradeCost(part, lvl)!;
    }
  }
  return total;
}
