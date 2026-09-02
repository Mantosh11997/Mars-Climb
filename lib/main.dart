import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/config.dart';
import 'game/progress/profile_store.dart';
import 'game/vehicle/vehicle.dart';
import 'ui/machine_select_screen.dart';
import 'ui/palette.dart';
import 'ui/progress_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hill-climb games want landscape and no system chrome.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Read the save before the first frame. The garage cannot be drawn
  // honestly without it - every card needs to know whether it is owned.
  final store = ProfileStore(starterVehicleId: rover.id);
  await store.load();

  runApp(MarsClimbApp(store: store));
}

class MarsClimbApp extends StatelessWidget {
  const MarsClimbApp({super.key, required this.store});

  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mars Climb',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Palette.pageGradient.first,
        colorScheme: ColorScheme.fromSeed(seedColor: GameConfig.accent),
      ),
      home: ProgressScope(
        store: store,
        child: const MachineSelectScreen(),
      ),
    );
  }
}
