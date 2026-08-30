/// Which build this is, stamped in at compile time.
///
/// A screenshot of the game should say which commit produced it. Without
/// that, "I installed it and nothing changed" is unanswerable: an APK that
/// is one run out of date and an APK where the change did not work look
/// exactly the same.
///
/// CI passes it as
///   --dart-define=BUILD_ID=<run number>·<short sha>
/// so the label on screen matches the artifact name in the Actions run.
/// Local builds get 'dev'.
const String buildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');
