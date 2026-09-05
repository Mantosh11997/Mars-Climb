import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Put real fonts into a widget test.
///
/// A widget test ships with one font: Ahem, which draws every glyph as a
/// filled box. That is deliberate - it makes layout tests independent of
/// what fonts a machine happens to have - and it is fine right up until the
/// point where you look at the output. Every preview and every captured
/// gameplay frame in this project was rendered with boxes where the text
/// and the icons should be, which is useless for a screenshot and hid the
/// fact that some labels were being clipped.
///
/// Flutter ships Roboto and the Material icon font in its own artifact
/// cache, so there is no download and no asset to commit; they are the same
/// files the app uses on a device.
///
/// Call from a test that is going to be *looked at*, never from one that
/// asserts on layout - real glyph metrics differ from Ahem's, so pinning a
/// pixel size against them would make the test depend on Flutter's bundled
/// font version.
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return; // Boxes, but still a picture.

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final f in files) {
      final file = File('${dir.path}/$f');
      if (!file.existsSync()) continue;
      any = true;
      loader.addFont(
        file.readAsBytes().then((b) => ByteData.view(Uint8List.fromList(b).buffer)),
      );
    }
    if (any) await loader.load();
  }

  // Every weight the UI asks for. FontLoader picks within a family by
  // weight, and with only Regular loaded a w900 heading comes out as
  // synthetic bold, which looks wrong in a screenshot in a way that is
  // hard to name and easy to see.
  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}
