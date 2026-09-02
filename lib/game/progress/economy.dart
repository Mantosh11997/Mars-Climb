import '../level/level.dart';

/// What a run pays out.
///
/// The whole earning side of the economy is these four numbers, kept in one
/// place so they can be balanced against the prices in upgrades.dart and
/// vehicle.dart rather than guessed at from three files.
class Payout {
  const Payout({
    required this.distance,
    required this.cans,
    required this.finish,
    required this.firstClear,
  });

  /// Coins for ground covered, whether or not you made it.
  final int distance;

  /// Coins for fuel cans picked up.
  final int cans;

  /// Coins for reaching the line at all.
  final int finish;

  /// One-off, the first time a course is cleared.
  final int firstClear;

  int get total => distance + cans + finish + firstClear;

  bool get isEmpty => total == 0;
}

/// Coins per metre reached. Deliberately low: distance is the consolation
/// prize, and clearing a course should be worth far more than crawling
/// most of the way up it.
const double coinsPerMetre = 0.25;

/// Coins per fuel can. Cans already pay you in oxygen, so this is a nudge
/// to go and get the awkward ones rather than the main income.
const int coinsPerCan = 25;

/// Base for reaching the line, before the per-level bonus.
const int finishBase = 100;

/// Extra per level number, so late courses are worth the trouble.
const int finishPerLevel = 25;

/// Paid once, the first time a course is cleared. Big enough that opening
/// a new course feels like it bought you something.
const int firstClearBonus = 250;

Payout payoutFor({
  required Level level,
  required double distance,
  required int cans,
  required bool finished,
  required bool alreadyCleared,
}) =>
    Payout(
      distance: (distance * coinsPerMetre).floor(),
      cans: cans * coinsPerCan,
      finish: finished ? finishBase + finishPerLevel * level.number : 0,
      firstClear: finished && !alreadyCleared ? firstClearBonus : 0,
    );
