import 'package:flutter/material.dart';

import '../game/progress/upgrades.dart';
import '../game/vehicle/vehicle.dart';
import 'palette.dart';
import 'progress_scope.dart';

/// The workshop: four parts, five levels each, spend here.
///
/// A sheet rather than a screen. Upgrading is something you do *to the
/// machine you are looking at*, so it should slide over the garage rather
/// than replace it and make you find your way back.
class UpgradeSheet extends StatelessWidget {
  const UpgradeSheet({super.key, required this.vehicle});

  final Vehicle vehicle;

  static Future<void> show(BuildContext context, Vehicle vehicle) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => UpgradeSheet(vehicle: vehicle),
      );

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final fitted = store.profile.upgradesFor(vehicle.id);
    final coins = store.profile.coins;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.line),
        boxShadow: Palette.lift(strong: true),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  vehicle.name.toUpperCase(),
                  style: const TextStyle(
                    color: Palette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.paid_rounded, size: 16, color: Palette.accent),
                const SizedBox(width: 5),
                Text(
                  '$coins',
                  style: const TextStyle(
                    color: Palette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final part in UpgradePart.values)
              _PartRow(
                vehicleId: vehicle.id,
                part: part,
                level: fitted.levelOf(part),
                coins: coins,
              ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'DONE',
                style: TextStyle(
                  color: Palette.inkMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.vehicleId,
    required this.part,
    required this.level,
    required this.coins,
  });

  final String vehicleId;
  final UpgradePart part;
  final int level;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final price = upgradeCost(part, level);
    final maxed = price == null;
    final affordable = !maxed && coins >= price;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.label,
                  style: const TextStyle(
                    color: Palette.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                // Pips rather than a bar: five discrete levels, and you
                // should be able to count what you have left at a glance.
                Row(
                  children: [
                    for (var i = 0; i < maxUpgradeLevel; i++)
                      Container(
                        width: 22,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: i < level ? Palette.accent : Palette.track,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  part.blurb,
                  style: const TextStyle(
                    color: Palette.inkFaint,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: affordable ? Palette.accent : Palette.track,
                foregroundColor:
                    affordable ? Palette.onAccent : Palette.inkFaint,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: affordable
                  ? () =>
                      ProgressScope.read(context).buyUpgrade(vehicleId, part)
                  : null,
              child: Text(
                maxed ? 'MAX' : '$price',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
