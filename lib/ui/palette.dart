import 'package:flutter/material.dart';

/// The one place the interface gets its colours.
///
/// Every screen, card, bar and button reads from here, so the whole shell
/// can be re-pitched by editing this file and nothing else. The game world
/// keeps its own palette in GameConfig and the per-level themes: those are
/// Mars, and Mars does not follow the menus.
///
/// This is the light theme - a sunlit Martian daylight: warm off-white
/// panels on a pale sand ground, deep-brown ink, and the same orange
/// accent the game world uses so the two read as one product.
class Palette {
  const Palette._();

  // --- page ground ----------------------------------------------------

  /// Top-to-bottom wash behind every menu screen: high pale sky settling
  /// into warm sand at the foot.
  static const List<Color> pageGradient = [
    Color(0xFFFFF6EC),
    Color(0xFFFBE6D2),
    Color(0xFFF2CFB0),
  ];

  /// Behind the running game, seen only in the letterbox.
  static const Color gameLetterbox = Color(0xFFF3D8BE);

  // --- surfaces -------------------------------------------------------

  /// Cards and panels. Nearly white, warmed so it does not read blue
  /// against the sand.
  static const Color surface = Color(0xFFFFFBF6);

  /// A panel over the running game, which needs to stay legible against
  /// whatever terrain is behind it.
  static const Color surfaceOverGame = Color(0xF2FFFBF6);

  /// The scrim that dims the game behind an outcome panel.
  static const Color scrim = Color(0xB3FFF1E2);

  /// Hairlines, card edges, and the unfilled part of a bar.
  static const Color line = Color(0xFFE6D2BC);
  static const Color track = Color(0xFFEADCCB);

  // --- ink ------------------------------------------------------------

  /// Headings and figures.
  static const Color ink = Color(0xFF2C1A11);

  /// Labels and body copy.
  static const Color inkMuted = Color(0xFF6E5544);

  /// Units, hints, the quiet half of a row.
  static const Color inkFaint = Color(0xFF9C8371);

  // --- accents --------------------------------------------------------

  /// Selection, fill, and the primary button. Matches GameConfig.accent so
  /// the shell and the world share a signature colour.
  static const Color accent = Color(0xFFFF8A3D);

  /// Text on top of [accent].
  static const Color onAccent = Color(0xFF2B1408);

  /// The brake control, and a failed run.
  static const Color danger = Color(0xFFC0392B);

  /// A finished course, and a healthy fuel bar.
  static const Color success = Color(0xFF17916F);

  /// Fuel running low.
  static const Color warning = Color(0xFFE08A00);

  // --- elevation ------------------------------------------------------

  /// Cards lift off a light ground with a shadow, not a glow: on a pale
  /// background a glow reads as a smudge.
  static List<BoxShadow> lift({bool strong = false}) => [
        BoxShadow(
          color: const Color(0xFF6B4326).withOpacity(strong ? 0.22 : 0.12),
          blurRadius: strong ? 26 : 14,
          offset: Offset(0, strong ? 10 : 5),
        ),
      ];
}
