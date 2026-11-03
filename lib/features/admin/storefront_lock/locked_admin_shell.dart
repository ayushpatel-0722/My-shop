import 'package:flutter/material.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../admin_shell.dart';
import 'storefront_lock_controller.dart';
import 'storefront_unlock_dialog.dart';

/// An [AdminShell] for a password-protected storefront section.
///
/// Same parameters as [AdminShell], plus:
///  * a lock icon in the app bar (closed = locked; tap to enter the password,
///    or — when open — to lock again);
///  * while locked the content can be seen behind a veil but not touched, and
///    the floating action button is hidden, so nothing can be changed;
///  * it starts locked every time the screen is opened.
class LockedAdminShell extends StatefulWidget {
  const LockedAdminShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBack = false,
    this.backRoute = AppRoutes.admin,
    this.floatingActionButton,
    this.controller,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBack;
  final String backRoute;
  final Widget? floatingActionButton;

  /// Tests pass their own; otherwise the shell makes (and disposes) one.
  final StorefrontLockController? controller;

  @override
  State<LockedAdminShell> createState() => _LockedAdminShellState();
}

class _LockedAdminShellState extends State<LockedAdminShell> {
  late final StorefrontLockController _lock =
      widget.controller ?? StorefrontLockController();

  @override
  void dispose() {
    if (widget.controller == null) _lock.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_lock.unlocked) {
      _lock.lock();
      messenger.showAppToast(
        SnackBar(
          content: Text(l10n.storefrontLockedAgainToast),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final ok = await showStorefrontUnlockDialog(context, _lock);
    if (ok && mounted) {
      messenger.showAppToast(
        SnackBar(
          content: Text(l10n.storefrontUnlockedToast),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _lock,
      builder: (context, _) {
        final unlocked = _lock.unlocked;
        return AdminShell(
          title: widget.title,
          showBack: widget.showBack,
          backRoute: widget.backRoute,
          actions: [
            IconButton(
              key: const Key('storefront-lock-button'),
              tooltip: unlocked
                  ? l10n.storefrontUnlockedTooltip
                  : l10n.storefrontLockTooltip,
              icon: Icon(
                unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: unlocked ? Colors.green.shade700 : null,
              ),
              onPressed: _toggle,
            ),
            // The app bar's own buttons (add, help, ...) are part of editing
            // too: dimmed and dead until unlocked.
            for (final action in widget.actions ?? const <Widget>[])
              IgnorePointer(
                ignoring: !unlocked,
                child: Opacity(opacity: unlocked ? 1 : 0.35, child: action),
              ),
          ],
          // Nothing to add while locked.
          floatingActionButton: unlocked ? widget.floatingActionButton : null,
          child: Stack(
            children: [
              // Visible but untouchable until unlocked.
              IgnorePointer(ignoring: !unlocked, child: widget.child),
              if (!unlocked) _veil(context, l10n),
            ],
          ),
        );
      },
    );
  }

  Widget _veil(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Positioned.fill(
      key: const Key('storefront-locked-overlay'),
      child: ColoredBox(
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 44,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.storefrontLockedTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.storefrontLockedHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('storefront-unlock-button'),
                        onPressed: _toggle,
                        icon: const Icon(Icons.lock_open_rounded, size: 18),
                        label: Text(l10n.storefrontUnlockButton),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
