import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../../app/l10n/l10n_service.dart';
import '../config/app_config.dart';

/// Force-update / feature-flag controller (Section 18.2).
class RemoteConfigService {
  final _rc = FirebaseRemoteConfig.instance;

  static const _keyMinVersion = 'minSupportedVersion';
  static const _keyForceUpdate = 'forceUpdate';
  static const _keyUpdateMessage = 'updateMessage';

  Future<void> init() async {
    await _rc.setDefaults({
      _keyMinVersion: AppConfig.minSupportedVersion,
      _keyForceUpdate: false,
      _keyUpdateMessage: L10n.current.aNewVersionIsAvailablePleaseUpdate,
    });
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 5),
      ),
    );
    await _rc.fetchAndActivate();
  }

  String get minSupportedVersion => _rc.getString(_keyMinVersion);
  bool get forceUpdate => _rc.getBool(_keyForceUpdate);
  String get updateMessage => _rc.getString(_keyUpdateMessage);
}
