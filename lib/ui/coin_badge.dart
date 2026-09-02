import 'package:flutter/material.dart';

import 'palette.dart';
import 'progress_scope.dart';

/// The wallet, shown in the corner of every screen you can spend on.
///
/// Reads the store directly rather than taking a number, so it can never
/// drift out of date after a purchase somewhere else on the screen.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final coins = ProgressScope.of(context).profile.coins;

    return GestureDetector(
      // Long press wipes the save. Hidden rather than absent because
      // testing the campaign gate means clearing it, and the alternative
      // is reinstalling the app every time.
      onLongPress: () => _confirmReset(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Palette.line),
          boxShadow: Palette.lift(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.paid_rounded, size: 17, color: Palette.accent),
            const SizedBox(width: 6),
            Text(
              '$coins',
              style: const TextStyle(
                color: Palette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final store = ProgressScope.read(context);
    final wipe = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.surface,
        title: const Text(
          'Reset progress?',
          style: TextStyle(color: Palette.ink, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Coins, machines, upgrades and every cleared course go back to '
          'nothing. There is no undo.',
          style: TextStyle(color: Palette.inkMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Palette.danger),
            ),
          ),
        ],
      ),
    );
    if (wipe ?? false) store.reset();
  }
}
