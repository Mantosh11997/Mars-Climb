import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/mars_climb_game.dart';
import 'ui/controls.dart';
import 'ui/outcome_overlay.dart';
import 'ui/hud.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hill-climb games want landscape and no system chrome.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MarsClimbApp());
}

class MarsClimbApp extends StatelessWidget {
  const MarsClimbApp({super.key});

  @override
  Widget build(BuildContext context) {
    final game = MarsClimbGame();

    return MaterialApp(
      title: 'Mars Climb',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF160B08),
        body: GameWidget<MarsClimbGame>(
          game: game,
          overlayBuilderMap: {
            Overlays.hud: (_, g) => Hud(game: g),
            Overlays.controls: (_, g) => Controls(game: g),
            Overlays.gameOver: (_, g) => OutcomeOverlay(game: g),
            Overlays.levelComplete: (_, g) => OutcomeOverlay(game: g),
          },
          loadingBuilder: (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF8A3D)),
          ),
        ),
      ),
    );
  }
}
