import 'package:flutter/material.dart';

import '../../../app/l10n/app_localizations.dart';
import 'storefront_lock_controller.dart';

/// Asks for the editing password. Resolves to true once the section is
/// unlocked, false if the admin gave up.
Future<bool> showStorefrontUnlockDialog(
  BuildContext context,
  StorefrontLockController controller,
) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UnlockDialog(controller: controller),
  );
  return ok == true;
}

class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog({required this.controller});

  final StorefrontLockController controller;

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _password = TextEditingController();
  bool _visible = false;
  UnlockResult? _error;

  @override
  void dispose() {
    _password.dispose(); // the typed password is not kept anywhere
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.controller.isChecking) return;
    final result = await widget.controller.tryUnlock(_password.text);
    if (!mounted) return;
    if (result == UnlockResult.unlocked) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = result);
      if (result == UnlockResult.wrongPassword) _password.clear();
    }
  }

  String? _message(AppLocalizations l10n) => switch (_error) {
    null || UnlockResult.unlocked => null,
    UnlockResult.wrongPassword => l10n.storefrontWrongPassword,
    UnlockResult.notConfigured => l10n.storefrontNotConfigured,
    UnlockResult.checkFailed => l10n.storefrontCheckFailed,
    UnlockResult.tooManyAttempts => l10n.storefrontTooManyAttempts(
      widget.controller.limiter.secondsLeft,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final checking = widget.controller.isChecking;
        final message = _message(l10n);
        return AlertDialog(
          key: const Key('storefront-unlock-dialog'),
          title: Row(
            children: [
              const Icon(Icons.lock_outline),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.storefrontUnlockTitle)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.storefrontUnlockBody),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('storefront-password-field'),
                  controller: _password,
                  autofocus: true,
                  obscureText: !_visible,
                  enableSuggestions: false,
                  autocorrect: false,
                  enabled: !checking,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.storefrontPasswordLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _visible ? 'Hide' : 'Show',
                      icon: Icon(
                        _visible ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _visible = !_visible),
                    ),
                  ),
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      message,
                      key: const Key('storefront-unlock-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('storefront-unlock-cancel'),
              onPressed: checking
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: const Key('storefront-unlock-submit'),
              onPressed: checking ? null : _submit,
              child: checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.storefrontUnlockAction),
            ),
          ],
        );
      },
    );
  }
}
