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
  String? _companyError;
  String? _companyPassError;
  String? _emailError;
  String? _passError;

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
            final msg =
                state.error != null &&
                    state.error!.isNotEmpty &&
                    state.error != 'invalid'
                ? state.error!
                : l10n.invalidCredentials;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
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
                    onChanged: (_) {
                      if (_companyError != null) {
                        setState(() => _companyError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).greenleafOrganics,
                      prefixIcon: const Icon(Icons.business),
                      errorText: _companyError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _companyPassCtrl,
                    obscureText: true,
                    onChanged: (_) {
                      if (_companyPassError != null) {
                        setState(() => _companyPassError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: l10n.companyPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: _companyPassError,
                    ),
                  ),
                ] else ...[
                  _label(context, '2 · ${l10n.email}'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).adminCompanyIn,
                      prefixIcon: const Icon(Icons.mail_outline),
                      errorText: _emailError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    onChanged: (_) {
                      if (_passError != null) {
                        setState(() => _passError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: _passError,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (loading || _validatingStep1) ? null : _next,
                  child: (loading || _validatingStep1)
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(_step == 1 ? l10n.next : l10n.login),
                ),
                if (_step == 2)
                  TextButton(
                    onPressed: () => setState(() {
                      _step = 1;
                      _emailError = null;
                      _passError = null;
                    }),
                    child: Text(l10n.back),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    ).hasMatch(email);
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (_step == 1) {
      final companyName = _companyCtrl.text.trim();
      final companyPass = _companyPassCtrl.text;
      String? companyErr;
      String? passErr;

      if (companyName.isEmpty) {
        companyErr = l10n.companyNameAndPasswordAreRequired;
      }
      if (companyPass.isEmpty) {
        passErr = l10n.companyPassword;
      }

      if (companyErr != null || passErr != null) {
        setState(() {
          _companyError = companyErr;
          _companyPassError = passErr;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseEnterCompanyNameAndCompanyPassword),
          ),
        );
        return;
      }

      setState(() => _validatingStep1 = true);
      try {
        final slug = companyName.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
        var docs =
            (await FirebaseFirestore.instance
                    .collection('companies')
                    .where('name', isEqualTo: companyName)
                    .get())
                .docs;
        if (docs.isEmpty) {
          docs =
              (await FirebaseFirestore.instance
                      .collection('companies')
                      .where('slug', isEqualTo: slug)
                      .get())
                  .docs;
        }
        if (docs.isEmpty) {
          docs =
              (await FirebaseFirestore.instance
                      .collection('companies')
                      .where('name', isEqualTo: companyName.toLowerCase())
                      .get())
                  .docs;
        }

        if (!mounted) return;

        if (docs.isEmpty) {
          setState(() {
            _companyError = l10n.companyNotFound(companyName);
          });
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.companyNotFound(companyName))),
          );
          return;
        }

        final passMatch = docs.any(
          (d) => (d.data()['companyPassword'] ?? '') == companyPass,
        );
        if (!passMatch) {
          setState(() {
            _companyPassError = l10n.incorrectCompanyPassword;
          });
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.incorrectCompanyPassword)),
          );
          return;
        }

        setState(() {
          _companyError = null;
          _companyPassError = null;
          _step = 2;
        });
      } catch (e) {
        debugPrint('Step 1 company check error: $e');
        if (mounted) {
          final errMsg = e.toString().contains('permission-denied')
              ? l10n.accessDeniedByServerPleaseCheckYourInternetConnectionAndTryAgain
              : l10n.couldNotVerifyCompanyPleaseTryAgain('$e');
          messenger.showSnackBar(SnackBar(content: Text(errMsg)));
        }
      } finally {
        if (mounted) setState(() => _validatingStep1 = false);
      }
    } else {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;
      String? emailErr;
      String? passErr;

      if (email.isEmpty) {
        emailErr = l10n.adminNameEmailAndPasswordAreRequired;
      } else if (!_isValidEmail(email)) {
        emailErr = l10n.pleaseEnterAdminEmailAndPassword;
      }

      if (pass.isEmpty) {
        passErr = l10n.password;
      } else if (pass.length < 6) {
        passErr = l10n.adminPasswordMustBeAtLeast6Characters;
      }

      if (emailErr != null || passErr != null) {
        setState(() {
          _emailError = emailErr;
          _passError = passErr;
        });
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.pleaseEnterAdminEmailAndPassword)),
        );
        return;
      }

      context.read<AuthCubit>().adminLogin(
        companyName: _companyCtrl.text.trim(),
        companyPassword: _companyPassCtrl.text,
        email: email,
        password: pass,
      );
    }
  }
}
