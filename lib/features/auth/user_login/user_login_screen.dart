import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../auth_cubit.dart';

/// User login via Mobile OTP (Section 5.3). Existence is checked before the
/// OTP is sent.
class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _mobileCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  bool _notFound = false;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.userLogin)),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            context.go(AppRoutes.home);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: l10n.mobileNumber,
                    prefixIcon: const Icon(Icons.phone_iphone),
                    suffixText: _notFound ? l10n.noAccountFound : null,
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                        hintText: l10n.enterOtp,
                        prefixIcon: const Icon(Icons.pin_outlined)),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _busy ? null : (_otpSent ? _verify : _sendOtp),
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(_otpSent ? l10n.verifyOtp : l10n.sendOtp),
                ),
                if (_otpSent)
                  TextButton(
                    onPressed: _resend,
                    child: Text(l10n.resendOtp),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(AppRoutes.userSignup),
                  child: Text(l10n.createAccountPrompt),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendOtp() async {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.isEmpty) return;
    setState(() {
      _busy = true;
      _notFound = false;
    });
    final exists = await context.read<AuthCubit>().userExists(mobile);
    setState(() => _busy = false);
    if (!exists) {
      setState(() => _notFound = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noAccountFound)),
      );
      return;
    }
    await context.read<AuthCubit>().sendOtp(mobile);
    setState(() => _otpSent = true);
  }

  Future<void> _resend() async {
    await context.read<AuthCubit>().sendOtp(_mobileCtrl.text.trim());
  }

  Future<void> _verify() async {
    final ok = await context
        .read<AuthCubit>()
        .verifyOtp(_mobileCtrl.text.trim(), _otpCtrl.text.trim());
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid OTP')));
    }
  }
}
