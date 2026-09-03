import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/level/level.dart';
import 'package:mars_climb/game/progress/player_profile.dart';
import 'package:mars_climb/game/progress/profile_store.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/ui/home_screen.dart';
import 'package:mars_climb/ui/progress_scope.dart';

/// The home screen's PLAY button chooses a course and a machine on your
/// behalf. That is a convenience right up until it picks wrong - sending
/// you to a course you have already cleared, or worse, launching a machine
/// you do not own - so the choice is pinned here rather than left to the
/// widget.
void main() {
  ProfileStore storeWith(PlayerProfile profile) {
    final store = ProfileStore(starterVehicleId: rover.id);
    if (profile.coins > 0) store.award(profile.coins);
    for (final id in profile.ownedVehicles) {
      store.buyVehicle(id, 0);
    }
    for (final n in profile.completedLevels) {
      store.recordRun(levelNumber: n, distance: 0, finished: true);
    }
    if (profile.lastVehicleId case final id?) store.setLastVehicle(id);
    return store;
  }

  Future<void> pump(WidgetTester tester, PlayerProfile profile) async {
    tester.view.physicalSize = const Size(1180, 540);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProgressScope(
        store: storeWith(profile),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('a fresh player is pointed at course one on the starter',
      (tester) async {
    await pump(tester, PlayerProfile.fresh);

    expect(tester.takeException(), isNull);
    expect(find.text('PLAY'), findsOneWidget);
    expect(
      find.text('${levels.first.name}  ·  ${rover.name}'),
      findsOneWidget,
    );
  });

  testWidgets('PLAY offers the first course not yet cleared', (tester) async {
    // A gap on purpose: 1 and 3 done, 2 failed. Taking "highest cleared
    // plus one" would skip straight past the course you are stuck on.
    await pump(
      tester,
      const PlayerProfile(completedLevels: {1, 3}),
    );

    // The button's own subtitle, not just the name anywhere on screen -
    // the UP NEXT panel names the same course, so a loose match would pass
    // on that alone even if PLAY pointed somewhere else.
    expect(
      find.text('${levels[1].name}  ·  ${rover.name}'),
      findsOneWidget,
      reason: 'the unfinished course between two cleared ones is next',
    );
  });

  testWidgets('PLAY never offers a machine that is not owned', (tester) async {
    // A save naming a machine that was never bought, which is what a
    // half-restored or edited profile looks like.
    await pump(
      tester,
      const PlayerProfile(lastVehicleId: 'stilt'),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('·  ${rover.name}'), findsOneWidget);
    expect(find.textContaining('Stilt'), findsNothing);
  });

  testWidgets('the last machine taken out is the one offered', (tester) async {
    await pump(
      tester,
      const PlayerProfile(
        ownedVehicles: {'rover', 'scout'},
        lastVehicleId: 'scout',
      ),
    );

    expect(find.textContaining('·  ${scout.name}'), findsOneWidget);
  });
}
