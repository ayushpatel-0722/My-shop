import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../services/auth_session.dart';

/// App-bar icon that takes an admin who is previewing the shopper app (via
/// "Shopper App" in the admin console) back to the admin console.
///
/// It renders nothing for shoppers, employees and signed-out visitors, so it
/// can sit in every shopper app bar without changing what they see.
class BackToAdminButton extends StatelessWidget {
  /// Colour of the icon; defaults to the surrounding icon theme.
  final Color? color;

  const BackToAdminButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthSession.instance,
      builder: (context, _) {
        if (!AuthSession.isAdmin) return const SizedBox.shrink();
        return IconButton(
          key: const Key('back-to-admin-button'),
          tooltip: AppLocalizations.of(context).adminConsole,
          icon: Icon(Icons.admin_panel_settings_outlined, color: color),
          onPressed: () => context.go(AppRoutes.admin),
        );
      },
    );
  }
}
