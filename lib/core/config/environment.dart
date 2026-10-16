import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import '../../firebase_options_uat.dart';
import '../../firebase_options_prod.dart';

/// The two environments the app can run under.
enum AppEnvironment { uat, prod }

/// Centralised, runtime-immutable environment configuration.
///
/// Call [EnvironmentConfig.init] **once** in the flavour-specific entry point
/// (`main_uat.dart` / `main_prod.dart`) before `runApp`.
class EnvironmentConfig {
  EnvironmentConfig._();

  /// Defaults to [AppEnvironment.uat] so that running `lib/main.dart` directly
  /// (without a flavour entry-point) falls back to the safer UAT environment.
  static AppEnvironment _current = AppEnvironment.uat;

  /// The active environment.
  static AppEnvironment get current => _current;

  /// Set the active environment. Must be called before [Firebase.initializeApp].
  static void init(AppEnvironment env) => _current = env;

  // ── Convenience getters ──────────────────────────────────────────────

  static bool get isUat => _current == AppEnvironment.uat;
  static bool get isProd => _current == AppEnvironment.prod;

  /// Human-readable label shown in the UI / app title.
  static String get appName => isUat ? 'Bazaar UAT' : 'Bazaar';

  /// Returns the correct [FirebaseOptions] for the active environment.
  static FirebaseOptions get firebaseOptions {
    switch (_current) {
      case AppEnvironment.uat:
        return UatFirebaseOptions.currentPlatform;
      case AppEnvironment.prod:
        return ProdFirebaseOptions.currentPlatform;
    }
  }

  /// Base URL for backend APIs (if applicable).
  static String get apiBaseUrl {
    switch (_current) {
      case AppEnvironment.uat:
        return 'https://uat-api.example.com';
      case AppEnvironment.prod:
        return 'https://api.example.com';
    }
  }
}
