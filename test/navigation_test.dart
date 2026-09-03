import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/progress/profile_store.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/main.dart';
import 'package:mars_climb/ui/progress_scope.dart';

/// Can everything that spends coins actually reach the profile?
///
/// This is a shape-of-the-tree bug rather than a logic one, and it is
/// invisible at the call site: `ProgressScope.of(context)` reads identically
/// whether the scope is above the caller or not. Put the scope at
/// MaterialApp's `home` and the first screen works perfectly while every
/// route pushed on top of it dies - dialogs, bottom sheets, the course
/// screen, the end-of-run payout. In a release build a widget that throws
/// during build is an unexplained grey box, which is exactly how it shipped.
///
/// So this pins the invariant two ways: structurally on the real app, and
/// behaviourally on each kind of route.
void main() {
  ProfileStore store() => ProfileStore(starterVehicleId: rover.id);

  testWidgets('the app puts the scope above MaterialApp', (tester) async {
    // Deliberately structural. It is the one assertion that would have
    // caught this without booting the garage, and it is the thing that is
    // easy to undo by accident later.
    await tester.pumpWidget(MarsClimbApp(store: store()));

    expect(
      find.ancestor(
        of: find.byType(MaterialApp),
        matching: find.byType(ProgressScope),
      ),
      findsOneWidget,
      reason: 'a scope below MaterialApp is invisible to every pushed route',
    );
  });

  group('a pushed', () {
    /// A minimal app shaped the way main.dart is, with a button that opens
    /// whatever route is under test.
    Future<void> pump(
        WidgetTester tester, VoidCallback Function(BuildContext) open) async {
      await tester.pumpWidget(
        ProgressScope(
          store: store(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: open(context),
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
    }

    /// Reads the store during build, which is what every real screen does.
    Widget reader() => Builder(
          builder: (context) =>
              Text('coins ${ProgressScope.of(context).profile.coins}'),
        );

    testWidgets('screen can reach the profile', (tester) async {
      await pump(
        tester,
        (context) => () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: reader()),
              ),
            ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('coins 0'), findsOneWidget);
    });

    testWidgets('dialog can reach the profile', (tester) async {
      await pump(
        tester,
        (context) => () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(content: reader()),
            ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('coins 0'), findsOneWidget);
    });

    testWidgets('bottom sheet can reach the profile', (tester) async {
      await pump(
        tester,
        (context) => () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => reader(),
            ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('coins 0'), findsOneWidget);
    });
  });

  testWidgets('a missing scope names itself rather than dying silently',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              Text('${ProgressScope.of(context).profile.coins}'),
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(
      '$error',
      contains('ProgressScope'),
      reason: 'a bare null dereference tells you nothing in a crash log',
    );
  });
}
