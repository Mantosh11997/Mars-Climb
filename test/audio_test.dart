import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mars_climb/game/audio/game_audio.dart';
import 'package:mars_climb/game/progress/player_profile.dart';
import 'package:mars_climb/game/progress/profile_store.dart';
import 'package:mars_climb/game/vehicle/vehicle.dart';
import 'package:mars_climb/ui/click.dart';
import 'package:mars_climb/ui/progress_scope.dart';
import 'package:mars_climb/ui/sound_toggle.dart';

/// Sound is decoration, and decoration must never be able to take the game
/// down. These pin the two ways it could: by throwing, and by making
/// something that used to build unbuildable.
void main() {
  group('GameAudio without a device', () {
    // Exactly the situation in a widget test, on a device with no audio
    // output, and on any platform where the plugin fails to open: warmUp
    // was never called or did not succeed, so there is no player behind
    // any of this.
    test('is inert rather than absent', () {
      final audio = GameAudio.instance;
      expect(audio.isReady, isFalse);

      // None of this should reach a plugin, and none of it should throw.
      for (final sfx in Sfx.values) {
        audio.play(sfx);
      }
      audio.startEngine();
      audio.setEngine(load: 1, speed: 0.8);
      audio.stopEngine();
      audio.setMuted(true);
      audio.setMuted(false);
    });

    test('every sound resolves to a file under assets/audio', () {
      for (final sfx in Sfx.values) {
        expect(sfx.path, startsWith('audio/'));
        expect(sfx.path, endsWith('.wav'));
      }
    });
  });

  group('clicky', () {
    test('passes null straight through', () {
      // A disabled button is disabled by having a null callback. Wrapping
      // that in a non-null closure would make every greyed-out button
      // pressable - it would click and do nothing.
      expect(clicky(null), isNull);
    });

    test('calls the action it wraps', () {
      var called = 0;
      clicky(() => called++)!();
      expect(called, 1);
    });
  });

  group('the sound setting', () {
    test('defaults on, and survives a save round trip', () {
      const on = PlayerProfile.fresh;
      expect(on.soundOn, isTrue, reason: 'a game that boots silent reads '
          'as broken rather than as considerate');

      final off = on.withSound(false);
      expect(PlayerProfile.fromJson(off.toJson()).soundOn, isFalse);
      expect(PlayerProfile.fromJson(on.toJson()).soundOn, isTrue);
    });

    test('a save written before sound existed comes back with sound on', () {
      // The real upgrade path: an installed player's save has no 'sound'
      // key at all, and must not be read as "this player chose silence".
      final old = <String, dynamic>{
        'coins': 400,
        'owned': ['rover'],
        'completed': [1],
        'best': {'1': 520.0},
        'upgrades': <String, dynamic>{},
      };
      expect(PlayerProfile.fromJson(old).soundOn, isTrue);
      expect(PlayerProfile.fromJson(old).coins, 400);
    });

    test('a junk value falls back to on rather than throwing', () {
      expect(
        PlayerProfile.fromJson({'sound': 'yes please'}).soundOn,
        isTrue,
      );
    });
  });

  group('SoundToggle', () {
    testWidgets('builds with no ProgressScope above it', (tester) async {
      // This is the regression. The toggle lives in the in-game HUD, and
      // the game is built standalone - terrain_streaming_test does exactly
      // that, with no scope anywhere. Requiring the store here made the
      // HUD, and so the whole game, impossible to build without saved
      // progress.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SoundToggle())),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SoundToggle), findsOneWidget);
    });

    testWidgets('reads and writes the profile when there is one',
        (tester) async {
      final store = ProfileStore(starterVehicleId: rover.id);
      await tester.pumpWidget(
        ProgressScope(
          store: store,
          child: const MaterialApp(home: Scaffold(body: SoundToggle())),
        ),
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byType(SoundToggle));
      await tester.pump();

      expect(store.profile.soundOn, isFalse);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

      await tester.tap(find.byType(SoundToggle));
      await tester.pump();

      expect(store.profile.soundOn, isTrue);
    });
  });
}
