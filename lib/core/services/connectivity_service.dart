import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity gate for critical writes (Section 20).
class ConnectivityService {
  final _conn = Connectivity();

  Future<bool> isOnline() async {
    final results = await _conn.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Stream<List<ConnectivityResult>> get onChanged => _conn.onConnectivityChanged;
}
