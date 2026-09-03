import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Every sound the game can make.
///
/// An enum rather than loose strings so a typo is a compile error, and so
/// the warm-up list cannot drift out of step with what actually gets
/// played - `Sfx.values` IS the list.
enum Sfx {
  /// A button was pressed. Fires constantly, so it is the quietest asset.
  tap('tap.wav'),

  /// A machine or an upgrade was bought.
  purchase('purchase.wav'),

  /// A fuel cell was picked up.
  coin('coin.wav'),

  /// The rover hit something hard, flipped, or fell.
  crash('crash.wav'),

  /// Course cleared.
  finish('finish.wav'),

  /// Run over without clearing it.
  fail('fail.wav'),

  /// Oxygen is nearly out.
  warning('warning.wav');

  const Sfx(this.file);

  final String file;

  String get path => 'audio/$file';
}

/// Plays the game's sound.
///
/// One instance, reached through [GameAudio.instance], because sound is
/// genuinely global: the garage, the course screen and the running game all
/// make noise and none of them should be handed an audio object to do it.
///
/// **Everything here is best-effort and never throws.** Audio is decoration.
/// A device with no audio output, a codec that will not open, a plugin
/// missing under a widget test - none of that is worth taking the game down
/// for, and a game that crashes because a coin chimed is a far worse bug
/// than a coin that did not. So every call into the plugin is wrapped, and
/// a failure sets [_broken], which quietly turns the whole service off for
/// the rest of the session rather than throwing once per frame.
class GameAudio {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  /// Off until [warmUp] succeeds. Tests, and any device where the plugin is
  /// unavailable, therefore never touch a player at all.
  bool _ready = false;

  /// Set when the plugin has failed once. It will fail again; there is no
  /// point finding out sixty times a second.
  bool _broken = false;

  /// The player's own mute. Kept separate from the saved preference so the
  /// service does not need to know that saved progress exists.
  bool _muted = false;

  bool get isMuted => _muted;

  final Map<Sfx, AudioPlayer> _players = {};
  AudioPlayer? _engine;

  /// Whether the engine loop is meant to be running. Tracked rather than
  /// asked of the player, because the answer is needed on the frame the
  /// call is made, not one event later.
  bool _engineOn = false;

  /// Load every clip and open a player for it.
  ///
  /// Called once at startup. Doing it lazily on first play meant the first
  /// coin of every run was silent while the file decoded, which read as
  /// "the sound is broken" rather than "the sound is late".
  Future<void> warmUp() async {
    if (_ready || _broken) return;
    try {
      await _load().timeout(const Duration(seconds: 5));
      _ready = true;
    } catch (e) {
      // Not rethrown: see the class comment. Logged, because a silent game
      // with no explanation is the hardest kind of bug to be told about.
      // Timed out as well as caught, because this runs before the first
      // frame - a plugin that never answers must not hold the app on a
      // blank screen forever.
      debugPrint('GameAudio: disabled ($e)');
      _broken = true;
    }
  }

  Future<void> _load() async {
    await AudioCache.instance.loadAll([for (final s in Sfx.values) s.path]);

    for (final sfx in Sfx.values) {
      // One player per sound, in low-latency mode: a shared player would
      // cut the finish jingle off to play a coin, and the general-purpose
      // mode has a delay you can hear on a button press.
      final player = AudioPlayer(playerId: 'sfx_${sfx.name}')
        ..setReleaseMode(ReleaseMode.stop);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setSource(AssetSource(sfx.path));
      _players[sfx] = player;
    }

    _engine = AudioPlayer(playerId: 'engine')..setReleaseMode(ReleaseMode.loop);
    await _engine!.setSource(AssetSource('audio/engine.wav'));
    await _engine!.setVolume(0);
  }

  /// Fire a one-shot.
  ///
  /// Re-triggering a sound that is already playing restarts it rather than
  /// layering, which is what you want for a coin picked up twice in a row
  /// and is why each sound gets its own player.
  void play(Sfx sfx, {double volume = 1.0}) {
    if (!_ready || _muted || _broken) return;
    final player = _players[sfx];
    if (player == null) return;
    unawaited(() async {
      try {
        await player.stop();
        await player.setVolume(volume.clamp(0.0, 1.0));
        await player.resume();
      } catch (e) {
        debugPrint('GameAudio: ${sfx.name} failed ($e)');
      }
    }());
  }

  // --- the engine loop -------------------------------------------------

  /// Start the engine loop, silent. [setEngine] gives it a volume.
  void startEngine() {
    if (!_ready || _broken || _engineOn) return;
    _engineOn = true;
    unawaited(() async {
      try {
        await _engine!.setVolume(0);
        await _engine!.resume();
      } catch (e) {
        debugPrint('GameAudio: engine failed ($e)');
        _engineOn = false;
      }
    }());
  }

  /// Follow the machine.
  ///
  /// [load] is 0 off-throttle and 1 on it; [speed] is the wheel speed as a
  /// fraction of this machine's top speed. Volume comes from the throttle
  /// and pitch from the speed, which is the right way round: a rover
  /// labouring against a slope is loud and low, and one freewheeling
  /// downhill is quiet and high.
  ///
  /// Called every frame, so it does nothing at all unless the value has
  /// moved enough to hear - pushing a set-volume call down the platform
  /// channel sixty times a second is both wasteful and audibly steppy.
  void setEngine({required double load, required double speed}) {
    if (!_ready || _broken || !_engineOn) return;

    final volume = _muted ? 0.0 : (0.16 + 0.52 * load.clamp(0.0, 1.0));
    final rate = (0.82 + 1.15 * speed.clamp(0.0, 1.4)).clamp(0.5, 2.2);

    if ((volume - _lastVolume).abs() > 0.04) {
      _lastVolume = volume;
      unawaited(_engine!.setVolume(volume).catchError((_) {}));
    }
    if ((rate - _lastRate).abs() > 0.05) {
      _lastRate = rate;
      // Not every platform can retune a playing sample. Where it cannot,
      // the loop simply stays at its recorded pitch and the volume still
      // tracks the throttle, which is most of the effect.
      unawaited(_engine!.setPlaybackRate(rate).catchError((_) {}));
    }
  }

  double _lastVolume = -1;
  double _lastRate = -1;

  void stopEngine() {
    if (!_engineOn) return;
    _engineOn = false;
    _lastVolume = -1;
    _lastRate = -1;
    unawaited(_engine?.stop().catchError((_) {}));
  }

  // --- mute ------------------------------------------------------------

  /// Silence everything, or let it speak again.
  ///
  /// Stops the engine immediately rather than turning it down, because a
  /// loop left running at zero volume still holds an audio focus session
  /// and still shows up as "this app is playing audio".
  void setMuted(bool muted) {
    if (_muted == muted) return;
    _muted = muted;
    if (!_ready || _broken) return;
    if (muted) {
      unawaited(_engine?.setVolume(0).catchError((_) {}));
      for (final p in _players.values) {
        unawaited(p.stop().catchError((_) {}));
      }
    }
    _lastVolume = -1;
  }

  /// For tests, which must not leave players open between cases.
  @visibleForTesting
  Future<void> disposeForTest() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
    await _engine?.dispose();
    _engine = null;
    _ready = false;
    _engineOn = false;
  }

  /// Whether a real player is behind this. Only tests should care.
  @visibleForTesting
  bool get isReady => _ready;
}
