import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/admin.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/modern_card.dart';
import '../../auth/auth_cubit.dart';
import '../admin_shell.dart';

/// Manage additional Admins for the same company (Section 4).
class AdminAdminsScreen extends StatelessWidget {
  const AdminAdminsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final companyId = context.read<AuthCubit>().currentUser?.companyId ?? '';
    final isDesktop = context.isDesktop;
    final theme = Theme.of(context);

    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).admins,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add Admin',
          onPressed: () => context.go(
            Uri(
              path: AppRoutes.adminSignup,
              queryParameters: {
                if (companyId.isNotEmpty) 'companyId': companyId,
              },
            ).toString(),
          ),
        ),
      ],
      child: StreamBuilder<List<Admin>>(
        stream: repo.admins(companyId),
        builder: (context, snap) {
          final list = snap.data ?? const <Admin>[];
          if (list.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context).noAdminsYet),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 16,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = list[i];
              return ModernCard(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 18 : 14,
                  vertical: isDesktop ? 14 : 12,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: isDesktop ? 24 : 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: isDesktop ? 24 : 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.email,
                            style: TextStyle(
                              fontSize: isDesktop ? 13.5 : 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 8,
                        vertical: isDesktop ? 4 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        AppLocalizations.of(context).admin,
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 10.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
