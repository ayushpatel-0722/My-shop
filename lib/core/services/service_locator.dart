import '../config/app_config.dart';
import '../database/firebase_app_repository.dart';
import '../database/mock_app_repository.dart';
import '../repositories/app_repository.dart';
import 'connectivity_service.dart';
import 'deep_link_service.dart';
import 'notification_service.dart';
import 'remote_config_service.dart';
import 'report_service.dart';

/// Dependency container. Call [init] once at startup (in main.dart).
class ServiceLocator {
  ServiceLocator._();
  static final ServiceLocator instance = ServiceLocator._();

  late AppRepository repository;
  late ConnectivityService connectivityService;
  late DeepLinkService deepLinkService;
  late ReportService reportService;

  NotificationService? notificationService;
  RemoteConfigService? remoteConfigService;

  /// [firebaseReady] is false when Firebase failed to initialize (e.g. the
  /// project has not been connected via `flutterfire configure` yet); in that
  /// case we fall back to the in-memory repository so the app still runs.
  void init({required bool firebaseReady}) {
    connectivityService = ConnectivityService();
    deepLinkService = DeepLinkService();
    reportService = ReportService();

    final useFirebase = firebaseReady && !AppConfig.useMockData;
    repository = useFirebase ? FirebaseAppRepository() : MockAppRepository();
    if (useFirebase) {
      notificationService = NotificationService();
      remoteConfigService = RemoteConfigService();
    }
  }
}

/// Convenience getters used across the app.
AppRepository get repo => ServiceLocator.instance.repository;
ConnectivityService get connectivity =>
    ServiceLocator.instance.connectivityService;
DeepLinkService get deepLinks => ServiceLocator.instance.deepLinkService;
ReportService get reports => ServiceLocator.instance.reportService;
