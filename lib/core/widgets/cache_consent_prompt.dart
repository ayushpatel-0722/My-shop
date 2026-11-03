import 'package:flutter/material.dart';

import '../../app/l10n/app_localizations.dart';
import '../cache/cache_consent.dart';
import '../cache/cache_consent_controller.dart';

/// Shows the cache-consent question over [child] while it is open — the app
/// is already running underneath, like a cookie notice on a website. Shows
/// nothing when there is no question (already answered, Android / iOS, tests).
class CacheConsentPrompt extends StatelessWidget {
  const CacheConsentPrompt({super.key, required this.child, this.controller});

  final Widget child;

  /// Defaults to [CacheConsentController.instance].
  final CacheConsentController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? CacheConsentController.instance;
    if (c == null) return child;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.needsPrompt) return child;
        return Stack(
          children: [
            // The app stays alive underneath but can not be tapped through.
            child,
            const ModalBarrier(color: Color(0x99000000), dismissible: false),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _ConsentCard(controller: c),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.controller});

  final CacheConsentController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = controller.busy;

    Widget category(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Card(
        key: const Key('cache-consent-dialog'),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cookie_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.cacheConsentTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(l10n.cacheConsentBody),
              category(
                Icons.lock_outline,
                l10n.cacheConsentEssentialTitle,
                l10n.cacheConsentEssentialBody,
              ),
              category(
                Icons.speed_outlined,
                l10n.cacheConsentSavedTitle,
                l10n.cacheConsentSavedBody,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.cacheConsentNote,
                key: const Key('cache-consent-note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('cache-consent-not-now'),
                    onPressed: busy
                        ? null
                        : () => controller.choose(CacheConsent.declined),
                    child: Text(l10n.cacheConsentNotNow),
                  ),
                  FilledButton(
                    key: const Key('cache-consent-allow'),
                    onPressed: busy
                        ? null
                        : () => controller.choose(CacheConsent.allowed),
                    child: Text(l10n.cacheConsentAllow),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
