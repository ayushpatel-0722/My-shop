import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/remote_config_service.dart';
import 'package:my_shop/app/l10n/app_localizations.dart';
import '../../app/l10n/l10n_service.dart';

/// Blocking "Update Required" screen (Section 18.2) shown when the installed
/// version is below the Remote Config minimum and `forceUpdate` is enabled.
class ForceUpdateGate extends StatefulWidget {
  final RemoteConfigService? remoteConfig;
  final Widget child;

  const ForceUpdateGate({
    super.key,
    required this.remoteConfig,
    required this.child,
  });

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  late final Future<bool> _needsUpdate;

  @override
  void initState() {
    super.initState();
    _needsUpdate = _check();
  }

  Future<bool> _check() async {
    final rc = widget.remoteConfig;
    if (rc == null) return false;
    if (!rc.forceUpdate) return false;
    final info = await PackageInfo.fromPlatform();
    return _compareVersions(info.version, rc.minSupportedVersion) < 0;
  }

  int _compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // When remoteConfig is null (e.g. web or mock mode), bypass gate immediately
    if (widget.remoteConfig == null) {
      return widget.child;
    }

    return FutureBuilder<bool>(
      future: _needsUpdate,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return widget.child;
        }
        if (snap.data == true) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _UpdateScreen(
              message:
                  widget.remoteConfig?.updateMessage ??
                  L10n.current.aNewVersionIsAvailable,
            ),
          );
        }
        return widget.child;
      },
    );
  }
}

class _UpdateScreen extends StatelessWidget {
  final String message;
  const _UpdateScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.system_update_alt, size: 72, color: scheme.primary),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context).updateRequired,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              // NOTE: link this to your Play Store / App Store listing.
              FilledButton(onPressed: () {}, child: Text(AppLocalizations.of(context).update)),
            ],
          ),
        ),
      ),
    );
  }
}
