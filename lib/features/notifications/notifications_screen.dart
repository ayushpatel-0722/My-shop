import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../core/models/notification.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/modern_shimmer.dart';
import '../auth/auth_cubit.dart';

/// In-app notification centre (Section 16).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
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
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  itemBuilder: (_, _) => const M3ListTileSkeleton(),
                );
              }
              final list = snap.data ?? const <AppNotification>[];
              if (list.isEmpty) {
                return const Center(child: Text('No notifications'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
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
                    onTap: () => repo.markNotificationRead(n.id),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
