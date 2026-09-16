/// Global build/configuration flags.
class AppConfig {
  AppConfig._();

  /// Set `true` to run the app against the in-memory mock repository without
  /// any Firebase backend (useful for UI-only demos). Defaults to `false` so
  /// the app uses the real Firebase backend.
  static const bool useMockData = false;

  /// Minimum app version enforced via Firebase Remote Config. Bump this to
  /// trigger the blocking "Update Required" screen on older builds.
  static const String minSupportedVersion = '1.0.0';

  /// Android App Check debug token (paste the token printed by the Firebase
  /// Console -> App Check -> Apps -> your debug app). Leave empty in release.
  static const String appCheckDebugTokenAndroid = '';

  /// iOS App Check debug token (same idea as above). Leave empty in release.
  static const String appCheckDebugTokenApple = '';

  static const String appName = 'Bazaar';
}
