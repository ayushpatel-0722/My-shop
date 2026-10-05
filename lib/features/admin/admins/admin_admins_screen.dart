import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/admin.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/auth_cubit.dart';
import '../admin_shell.dart';

/// Manage additional Admins for the same company (Section 4).
class AdminAdminsScreen extends StatelessWidget {
  const AdminAdminsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final companyId = context.read<AuthCubit>().currentUser?.companyId ?? '';
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).admins,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
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
            return Center(child: Text(AppLocalizations.of(context).noAdminsYet));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final a = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.admin_panel_settings)),
                  title: Text(a.name),
                  subtitle: Text(a.email),
                  trailing: Chip(label: Text(AppLocalizations.of(context).admin)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
