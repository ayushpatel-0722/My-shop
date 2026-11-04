import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../core/models/notification.dart';
import '../../core/services/service_locator.dart';
import '../../core/utils/responsive_extensions.dart';
import '../../core/widgets/back_to_admin_button.dart';
import '../../core/widgets/modern_shimmer.dart';
import '../auth/auth_cubit.dart';
import '../marketplace/widgets/web_header.dart';

/// In-app notification centre (Section 16).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Opened from a deep link or a push there is nothing to go back to: the
    // phone's back gesture must then land on the home screen, not close the
    // app.
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: context.isDesktop
            ? const PreferredSize(
                preferredSize: Size.fromHeight(64),
                child: WebHeader(),
              )
            : AppBar(
                title: Text(l10n.notificationCentre),
                leading: BackButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.home);
                    }
                  },
                ),
                actions: const [BackToAdminButton()],
              ),
        body: Builder(
          builder: (context) {
            final userId = context.read<AuthCubit>().currentUser?.id ?? 'guest';
            return StreamBuilder<List<AppNotification>>(
              stream: repo.notifications(userId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.isDesktop ? 24 : 16,
                      vertical: 16,
                    ),
                    itemCount: 5,
                    itemBuilder: (_, _) => const M3ListTileSkeleton(),
                  );
                }
                final list = snap.data ?? const <AppNotification>[];
                if (list.isEmpty) {
                  return Center(
                    child: Text(AppLocalizations.of(context).noNotifications),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isDesktop ? 24 : 8,
                    vertical: 8,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final n = list[i];
                    return ListTile(
                      leading: Icon(
                        n.isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight: n.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(n.body),
                      onTap: () => _open(context, n),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Marks the notification read and opens the screen it points to (an order,
  /// a product…), on top of this one so back returns here.
  void _open(BuildContext context, AppNotification n) {
    repo.markNotificationRead(n.id);
    final link = n.deepLink.trim();
    if (link.isEmpty) return;
    final uri = Uri.tryParse(link);
    final route = uri == null ? null : deepLinks.toRoute(uri);
    if (route == null || route.isEmpty) return;
    try {
      context.push(route);
    } catch (_) {}
  }
}
