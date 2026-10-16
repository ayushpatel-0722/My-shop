import 'core/config/environment.dart';
import 'main.dart' as app;

/// Entry point for the **PROD** flavour.
///
/// Run with:
/// ```bash
/// flutter run --flavor prod -t lib/main_prod.dart
/// ```
Future<void> main() async {
  EnvironmentConfig.init(AppEnvironment.prod);
  await app.main();
}
