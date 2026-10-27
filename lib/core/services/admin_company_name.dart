import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import 'service_locator.dart';

/// Resolves the shop name for the signed-in admin.
///
/// A user record normally carries `companyName`, but some admin accounts only
/// store `companyId`. In that case the name is looked up once from the company
/// record and cached, and listeners are notified when it arrives.
class AdminCompanyName extends ChangeNotifier {
  AdminCompanyName._();
  static final AdminCompanyName instance = AdminCompanyName._();

  final Map<String, String> _cache = <String, String>{};
  final Set<String> _loading = <String>{};

  /// The best name available right now; empty while it is still loading.
  String nameFor(AppUser? user) {
    if (user == null) return '';
    if (user.companyName.isNotEmpty) return user.companyName;
    if (user.companyId.isEmpty) return '';
    final cached = _cache[user.companyId];
    if (cached == null) _load(user.companyId);
    return cached ?? '';
  }

  Future<void> _load(String companyId) async {
    if (!_loading.add(companyId)) return;
    try {
      final company = await repo.company(companyId);
      _cache[companyId] = company?.name ?? '';
    } catch (_) {
      _cache[companyId] = '';
    } finally {
      _loading.remove(companyId);
      notifyListeners();
    }
  }

  /// [nameFor], or [fallback] (default: the app name) while no name is known.
  String displayName(AppUser? user, {String? fallback}) {
    final name = nameFor(user);
    return name.isNotEmpty ? name : (fallback ?? AppConfig.appName);
  }
}
