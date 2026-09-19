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
          final isAuthenticating = state.status == AuthStatus.authenticating;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _mobileCtrl,
                  readOnly: _otpSent || _busy || isAuthenticating,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '9876543210',
                    prefixIcon: const Icon(Icons.phone_iphone),
                    prefixText: '+91  ',
                    suffixIcon: _otpSent
                        ? TextButton(
                            onPressed: _busy || isAuthenticating
                                ? null
                                : _changeNumber,
                            child: const Text('Change'),
                          )
                        : null,
                    errorText: _notFound && !_otpSent
                        ? AppLocalizations.of(context).noAccountFound
                        : null,
                    helperText: _otpSent ? null : 'Enter 10-digit number',
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: !_busy && !isAuthenticating,
                    decoration: const InputDecoration(
                      labelText: 'OTP',
                      hintText: '------',
                      prefixIcon: Icon(Icons.pin_outlined),
                      helperText: 'Enter the 6-digit code sent via SMS',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_busy || isAuthenticating)
                      ? null
                      : (_otpSent ? _verify : _sendOtp),
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(_otpSent ? l10n.verifyOtp : l10n.sendOtp),
                ),
                if (_otpSent)
                  TextButton(
                    onPressed: (_busy || isAuthenticating) ? null : _resend,
                    child: Text(l10n.resendOtp),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: isAuthenticating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.g_mobiledata,
                          size: 28,
                          color: Colors.red,
                        ),
                  label: Text(
                    isAuthenticating ? 'Signing in...' : 'Sign in with Google',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: (_busy || isAuthenticating)
                      ? null
                      : () =>
                            context.read<AuthCubit>().signInWithGoogle(context),
                ),
                const SizedBox(height: 20),
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

  void _changeNumber() {
    setState(() {
      _otpSent = false;
      _otpCtrl.clear();
      _notFound = false;
    });
  }

  /// Validates an Indian mobile number.
  /// Accepts 10-digit numbers starting with 6–9, or numbers already prefixed
  /// with +91 (e.g. "+919876543210").
  bool _isValidMobile(String raw) {
    final clean = raw.replaceAll(RegExp(r'[\s\-().]+'), '');
    // Strip leading +91 or 0 for digit-count check.
    final digits = clean.startsWith('+91')
        ? clean.substring(3)
        : clean.startsWith('91') && clean.length == 12
        ? clean.substring(2)
        : clean.startsWith('0')
        ? clean.substring(1)
        : clean;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits);
  }

  Future<void> _sendOtp() async {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile number')),
      );
      return;
    }
    if (!_isValidMobile(mobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid 10-digit Indian mobile number (e.g. 9876543210)',
          ),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _notFound = false;
    });
    try {
      final exists = await context.read<AuthCubit>().userExists(mobile);
      if (!mounted) return;
      if (!exists) {
        setState(() => _notFound = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).noAccountFound),
            action: SnackBarAction(
              label: AppLocalizations.of(context).createAccount,
              onPressed: () => context.go(AppRoutes.userSignup),
            ),
          ),
        );
        return;
      }
      final ok = await context.read<AuthCubit>().sendOtp(mobile);
      if (!mounted) return;
      if (ok) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $mobile'),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send OTP. Please verify your number or try again.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.isEmpty) return;
    setState(() => _busy = true);
    try {
      final ok = await context.read<AuthCubit>().sendOtp(mobile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'OTP resent to $mobile' : 'Could not resend OTP. Try again.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await context.read<AuthCubit>().verifyOtp(
        _mobileCtrl.text.trim(),
        otp,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid OTP. Please check the code and try again.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification error: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
