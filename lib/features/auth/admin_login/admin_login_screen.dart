import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../auth_cubit.dart';

/// Two-step Admin login (Section 5.1):
/// Step 1 — Company Name + Company Password (tenant resolution).
/// Step 2 — Admin Email + Password (personal credential).
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _companyCtrl = TextEditingController();
  final _companyPassCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  int _step = 1;
  bool _validatingStep1 = false;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _companyPassCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminLogin)),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            context.go(AppRoutes.admin);
          } else if (state.status == AuthStatus.error) {
            final msg = state.error != null &&
                    state.error!.isNotEmpty &&
                    state.error != 'invalid'
                ? state.error!
                : l10n.invalidCredentials;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          }
        },
        builder: (context, state) {
          final loading = state.status == AuthStatus.authenticating;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 1) ...[
                  _label(context, '1 · ${l10n.companyName}'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _companyCtrl,
                    decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).greenleafOrganics,
                        prefixIcon: const Icon(Icons.business)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _companyPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                        hintText: l10n.companyPassword,
                        prefixIcon: const Icon(Icons.lock_outline)),
                  ),
                ] else ...[
                  _label(context, '2 · ${l10n.email}'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).adminCompanyIn,
                        prefixIcon: const Icon(Icons.mail_outline)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                        hintText: l10n.password,
                        prefixIcon: const Icon(Icons.lock_outline)),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (loading || _validatingStep1) ? null : _next,
                  child: (loading || _validatingStep1)
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(_step == 1 ? l10n.next : l10n.login),
                ),
                if (_step == 2)
                  TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: Text(l10n.back),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w600));

  Future<void> _next() async {
    if (_step == 1) {
      final companyName = _companyCtrl.text.trim();
      final companyPass = _companyPassCtrl.text;
      if (companyName.isEmpty || companyPass.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).pleaseEnterCompanyNameAndCompanyPassword),
          ),
        );
        return;
      }

      setState(() => _validatingStep1 = true);
      try {
        final slug =
            companyName.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
        var docs = (await FirebaseFirestore.instance
                .collection('companies')
                .where('name', isEqualTo: companyName)
                .get())
            .docs;
        if (docs.isEmpty) {
          docs = (await FirebaseFirestore.instance
                  .collection('companies')
                  .where('slug', isEqualTo: slug)
                  .get())
              .docs;
        }
        if (docs.isEmpty) {
          docs = (await FirebaseFirestore.instance
                  .collection('companies')
                  .where('name', isEqualTo: companyName.toLowerCase())
                  .get())
              .docs;
        }

        if (docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).companyNotFound('${companyName}'))),
            );
          }
          return;
        }

        final passMatch = docs.any(
            (d) => (d.data()['companyPassword'] ?? '') == companyPass);
        if (!passMatch) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).incorrectCompanyPassword)),
            );
          }
          return;
        }

        if (mounted) setState(() => _step = 2);
      } catch (e) {
        debugPrint('Step 1 company check error: $e');
        final errMsg = e.toString().contains('permission-denied')
            ? AppLocalizations.of(context).accessDeniedByServerPleaseCheckYourInternetConnectionAndTryAgain
            : AppLocalizations.of(context).couldNotVerifyCompanyPleaseTryAgain('${e}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg)),
          );
        }
      } finally {
        if (mounted) setState(() => _validatingStep1 = false);
      }
    } else {
      if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).pleaseEnterAdminEmailAndPassword),
          ),
        );
        return;
      }
      context.read<AuthCubit>().adminLogin(
            companyName: _companyCtrl.text.trim(),
            companyPassword: _companyPassCtrl.text,
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
    }
  }
}
