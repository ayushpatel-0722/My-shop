import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';

/// A thin bar saying the device is offline, so saved data that is still shown
/// is not mistaken for live data. Shows nothing while online (or when the
/// connectivity plugin is unavailable).
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({
    super.key,
    required this.child,
    this.checkConnectivity,
    this.changes,
  });

  final Widget child;

  /// Test hooks; default to connectivity_plus.
  final Future<bool> Function()? checkConnectivity;
  final Stream<bool>? changes;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _offline = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final online = await (widget.checkConnectivity ?? _defaultCheck)();
      if (mounted) setState(() => _offline = !online);
      final stream =
          widget.changes ??
          Connectivity().onConnectivityChanged.map(
            (r) => !r.contains(ConnectivityResult.none),
          );
      _sub = stream.listen((online) {
        if (mounted) setState(() => _offline = !online);
      }, onError: (_) {});
    } catch (_) {
      // No connectivity information: never show a false "offline".
    }
  }

  static Future<bool> _defaultCheck() async =>
      !(await Connectivity().checkConnectivity()).contains(
        ConnectivityResult.none,
      );

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_offline)
          Material(
            color: const Color(0xFF334155),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context).offlineShowingSaved,
                        key: const Key('offline-banner'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
