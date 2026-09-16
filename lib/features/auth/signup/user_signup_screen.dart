import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../auth_cubit.dart';

/// User Create Account (Section 5.5): Name + Mobile -> OTP -> verified, then
/// the /users document is written and the shopper enters the app.
class UserSignupScreen extends StatefulWidget {
  const UserSignupScreen({super.key});

  @override
  State<UserSignupScreen> createState() => _UserSignupScreenState();
}

class _UserSignupScreenState extends State<UserSignupScreen> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createAccount)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                  hintText: l10n.name, prefixIcon: const Icon(Icons.person)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  hintText: l10n.mobileNumber,
                  prefixIcon: const Icon(Icons.phone_iphone)),
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
                onPressed: () =>
                    context.read<AuthCubit>().sendOtp(_mobileCtrl.text.trim()),
                child: Text(l10n.resendOtp),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (_nameCtrl.text.isEmpty || _mobileCtrl.text.isEmpty) return;
    setState(() => _busy = true);
    final ok = await context.read<AuthCubit>().sendOtp(_mobileCtrl.text.trim());
    setState(() {
      _busy = false;
      if (ok) _otpSent = true;
    });
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send OTP. Try again.')),
      );
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final ok = await context
        .read<AuthCubit>()
        .verifyOtp(_mobileCtrl.text.trim(), _otpCtrl.text.trim());
    if (!ok) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invalid OTP')));
      }
      return;
    }
    // Verified — persist the customer's name against the new account.
    await context
        .read<AuthCubit>()
        .createUserAccount(_nameCtrl.text.trim(), _mobileCtrl.text.trim());
    if (!mounted) return;
    context.go(AppRoutes.home);
  }
}
