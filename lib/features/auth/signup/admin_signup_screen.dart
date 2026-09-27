import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/admin.dart';
import '../../../core/services/secure_session_cache.dart';
import '../auth_cubit.dart';

/// Admin Create Account (Section 5.4) — the founding Admin of a company, or an
/// additional Admin created by an existing one.
class AdminSignupScreen extends StatefulWidget {
  final String companyId;
  final String companyName;
  const AdminSignupScreen(
      {super.key, this.companyId = '', this.companyName = ''});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
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
            if (widget.companyName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(AppLocalizations.of(context).company3('${widget.companyName}'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                    hintText: l10n.name,
                    prefixIcon: const Icon(Icons.person))),
            const SizedBox(height: 16),
            TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    hintText: l10n.email,
                    prefixIcon: const Icon(Icons.mail_outline))),
            const SizedBox(height: 16),
            TextField(
                controller: _mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    hintText: l10n.mobileNumber,
                    prefixIcon: const Icon(Icons.phone_iphone))),
            const SizedBox(height: 16),
            TextField(
                controller: _addressCtrl,
                decoration: InputDecoration(
                    hintText: l10n.address,
                    prefixIcon: const Icon(Icons.location_on_outlined))),
            const SizedBox(height: 16),
            TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                    hintText: l10n.password,
                    prefixIcon: const Icon(Icons.lock_outline))),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      return;
    }
    final authCubit = context.read<AuthCubit>();
    final messenger = ScaffoldMessenger.of(context);
    var effectiveCompanyId = widget.companyId.isNotEmpty
        ? widget.companyId
        : (authCubit.currentUser?.companyId ?? '');
    if (effectiveCompanyId.isEmpty) {
      final cached = await SecureSessionCache.instance.restore();
      if (cached != null && cached.companyId.isNotEmpty) {
        effectiveCompanyId = cached.companyId;
      }
    }
    if (effectiveCompanyId.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context).noCompanyIdentifiedPleaseEnsureYouAreLoggedInToYourCompany),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await authCubit.createAdminAccount(
            Admin(
              id: '',
              companyId: effectiveCompanyId,
              name: _nameCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              mobileNumber: _mobileCtrl.text.trim(),
              address: _addressCtrl.text.trim(),
            ),
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      context.go(AppRoutes.admin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorCreatingAdmin('${e}'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
