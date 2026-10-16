import 'core/config/environment.dart';
import 'main.dart' as app;

/// Entry point for the **UAT** flavour.
///
/// Run with:
/// ```bash
/// flutter run --flavor uat -t lib/main_uat.dart
/// ```
Future<void> main() async {
  EnvironmentConfig.init(AppEnvironment.uat);
  await app.main();
}
