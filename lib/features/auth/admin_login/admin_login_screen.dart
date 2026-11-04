import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/services/company_password.dart';
import '../auth_cubit.dart';
import '../widgets/auth_page_shell.dart';

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
    return BlocConsumer<AuthCubit, AuthState>(
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
          ).showAppToast(SnackBar(content: Text(msg)));
        }
      },
      builder: (context, state) {
        final loading = state.status == AuthStatus.authenticating;
        final busy = loading || _validatingStep1;
        return AuthPageShell(
          title: l10n.adminLogin,
          subtitle: l10n.authAdminSubtitle,
          icon: Icons.admin_panel_settings,
          badge: l10n.authRoleAdmin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthStepBar(
                current: _step - 1,
                labels: [l10n.authStepCompany, l10n.authStepAccount],
              ),
              const SizedBox(height: 20),
              if (_step == 1) ...[
                TextField(
                  controller: _companyCtrl,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_companyError != null) {
                      setState(() => _companyError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.companyName,
                    hintText: l10n.greenleafOrganics,
                    prefixIcon: const Icon(Icons.business),
                    errorText: _companyError,
                  ),
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _companyPassCtrl,
                  label: l10n.companyPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => busy ? null : _next(),
                  errorText: _companyPassError,
                  onChanged: (_) {
                    if (_companyPassError != null) {
                      setState(() => _companyPassError = null);
                    }
                  },
                ),
              ] else ...[
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    hintText: l10n.adminCompanyIn,
                    prefixIcon: const Icon(Icons.mail_outline),
                    errorText: _emailError,
                  ),
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _passCtrl,
                  label: l10n.password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => busy ? null : _next(),
                  errorText: _passError,
                  onChanged: (_) {
                    if (_passError != null) {
                      setState(() => _passError = null);
                    }
                  },
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: busy ? null : _next,
                child: busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(_step == 1 ? l10n.next : l10n.login),
              ),
              if (_step == 2) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _step = 1;
                    _emailError = null;
                    _passError = null;
                  }),
                  child: Text(l10n.back),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

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
        messenger.showAppToast(
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
          messenger.showAppToast(
            SnackBar(content: Text(l10n.companyNotFound(companyName))),
          );
          return;
        }

        final passMatch = docs.any(
          (d) => CompanyPassword.verify(
            companyPass,
            (d.data()['companyPassword'] ?? '').toString(),
          ),
        );
        if (!passMatch) {
          setState(() {
            _companyPassError = l10n.incorrectCompanyPassword;
          });
          messenger.showAppToast(
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
          messenger.showAppToast(SnackBar(content: Text(errMsg)));
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
        messenger.showAppToast(
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
