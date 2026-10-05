import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../auth_cubit.dart';

/// Single-step Employee login (Section 5.2): Company + Email + Password.
class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final _companyCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _companyError;
  String? _emailError;
  String? _passError;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    ).hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.employeeLogin)),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            context.go(AppRoutes.employeeHome);
          } else if (state.status == AuthStatus.error) {
            final msg =
                state.error != null &&
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
                TextField(
                  controller: _companyCtrl,
                  onChanged: (_) {
                    if (_companyError != null) {
                      setState(() => _companyError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: l10n.companyName,
                    prefixIcon: const Icon(Icons.business),
                    errorText: _companyError,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: l10n.email,
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading ? null : _login,
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(l10n.login),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _login() {
    final l10n = AppLocalizations.of(context);
    final company = _companyCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    String? companyErr;
    String? emailErr;
    String? passErr;

    if (company.isEmpty) {
      companyErr = l10n.companyNameAndPasswordAreRequired;
    }

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

    if (companyErr != null || emailErr != null || passErr != null) {
      setState(() {
        _companyError = companyErr;
        _emailError = emailErr;
        _passError = passErr;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidCredentials)),
      );
      return;
    }

    context.read<AuthCubit>().employeeLogin(
          companyName: company,
          email: email,
          password: pass,
        );
  }
}
