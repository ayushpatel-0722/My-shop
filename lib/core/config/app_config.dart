import 'environment.dart';

/// Global build/configuration flags.
class AppConfig {
  AppConfig._();

  /// Set `true` to run the app against the in-memory mock repository without
  /// any Firebase backend (useful for UI-only demos). Defaults to `false` so
  /// the app uses the real Firebase backend. Override at build time with
  /// `--dart-define=USE_MOCK_DATA=true` (see `make run-mock`).
  static const bool useMockData = bool.fromEnvironment('USE_MOCK_DATA');

  /// Minimum app version enforced via Firebase Remote Config. Bump this to
  /// trigger the blocking "Update Required" screen on older builds.
  static const String minSupportedVersion = '1.0.0';

  /// Android App Check debug token (paste the token printed by the Firebase
  /// Console -> App Check -> Apps -> your debug app). Leave empty in release.
  static const String appCheckDebugTokenAndroid = '';

  /// iOS App Check debug token (same idea as above). Leave empty in release.
  static const String appCheckDebugTokenApple = '';

  /// Application display name. Derived from the active environment so UAT
  /// builds are clearly distinguishable from production.
  static String get appName => EnvironmentConfig.appName;

  /// The active environment.
  static AppEnvironment get environment => EnvironmentConfig.current;

  /// Whether the app is running in the UAT environment.
  static bool get isUat => EnvironmentConfig.isUat;

  /// Whether the app is running in the PROD environment.
  static bool get isProd => EnvironmentConfig.isProd;
}
