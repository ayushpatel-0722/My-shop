import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_session.dart';
import 'deep_link_service.dart';

/// Turns incoming links (cold start and while running) into navigation.
///
/// - waits for app start-up to finish first, otherwise the router's boot
///   redirect would send a logged-in shopper from the product back to Home;
/// - ignores the same link arriving twice (some platforms deliver the launch
///   link through both the initial-link call and the stream);
/// - ignores links that are not for this app, and opens the shop page for a
///   product / category link whose id is missing.
class DeepLinkHandler {
  DeepLinkHandler({
    required this.service,
    required this.navigate,
    required this.currentLocation,
    Future<void> Function()? ready,
    this.dedupeWindow = const Duration(seconds: 3),
    DateTime Function()? now,
    Uri? browserUri,
  }) : _ready = ready ?? _appBooted,
       _now = now ?? DateTime.now,
       _browserUri = browserUri ?? (kIsWeb ? Uri.base : null);

  final DeepLinkService service;

  /// Opens a route (on top of the current screen).
  final void Function(String location) navigate;

  /// The route currently shown.
  final String Function() currentLocation;

  final Duration dedupeWindow;
  final Future<void> Function() _ready;
  final DateTime Function() _now;

  /// On the web: the address the page was opened with. A shared product link
  /// (`https://<domain>/shop/<shop>/product/<id>`) has its route in the path,
  /// while the app's own URLs keep it after `#`, so it is handled like a launch
  /// link.
  final Uri? _browserUri;

  StreamSubscription<Uri>? _sub;
  String? _lastRoute;
  DateTime? _lastAt;

  /// Starts listening: the launch link first, then links while running.
  void start() {
    final web = _browserUri;
    if (web != null && web.fragment.isEmpty && web.pathSegments.isNotEmpty) {
      handle(web);
    }
    _sub = service.stream.listen(handle, onError: (_) {});
    service
        .getInitialLink()
        .then((uri) {
          if (uri != null) handle(uri);
        })
        .catchError((_) {});
  }

  void dispose() => _sub?.cancel();

  /// Handles one link.
  Future<void> handle(Uri uri) async {
    final route = service.toRoute(uri);
    if (route == null) return;

    final last = _lastAt;
    if (route == _lastRoute &&
        last != null &&
        _now().difference(last) < dedupeWindow) {
      return; // same link again
    }
    _lastRoute = route;
    _lastAt = _now();

    await _ready();
    if (_sameLocation(currentLocation(), route)) return; // already there
    navigate(route);
  }

  static bool _sameLocation(String a, String b) =>
      Uri.tryParse(a)?.toString() == Uri.tryParse(b)?.toString();

  /// Completes once the session is restored and the router has done its
  /// start-up redirect (or after a safety timeout).
  static Future<void> _appBooted() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while ((AuthSession.isRestoring || !AuthSession.hasCompletedInitialBoot) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('Deep link: app ready');
  }
}
