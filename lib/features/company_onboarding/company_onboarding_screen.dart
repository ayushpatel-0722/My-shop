import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' show FirebaseDatabase;

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../core/models/admin.dart';
import '../../core/models/app_user.dart';
import '../../core/models/company.dart';
import '../../core/repositories/app_repository.dart';
import '../auth/auth_cubit.dart';

/// Company onboarding wizard (Section 8): basic details, weekly hours,
/// delivery types, currency, tenant password and logo. On success it hands off
/// to the Admin Create-Account flow.
class CompanyOnboardingScreen extends StatefulWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  State<CompanyOnboardingScreen> createState() =>
      _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState extends State<CompanyOnboardingScreen> {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  // Company image URL (optional) — replace image upload with URL input.
  final _imageUrlCtrl = TextEditingController();
  String _currency = 'INR';
  List<WeeklyHours> _hours = Company.defaultWeek();
  final Set<String> _deliveryTypes = {'self_pickup', 'home_delivery'};
  bool _busy = false;

  // First admin fields
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();
  final _adminPassConfirmCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _detailsCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _imageUrlCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPassCtrl.dispose();
    _adminPassConfirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.createNewCompany} (${_step + 1}/3)')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _stepBody(context, l10n)),
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: Text(l10n.back),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _step < 2 ? _next : _finish,
                    child: Text(_step < 2 ? l10n.next : l10n.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody(BuildContext context, AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return ListView(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.companyName,
                prefixIcon: const Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _detailsCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.appSubtitle,
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: l10n.address,
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
            ),
          ],
        );
      case 1:
        return ListView(
          children: [
            Text(l10n.openNow, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < _hours.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 48, child: Text(_hours[i].day)),
                    Switch(
                      value: !_hours[i].isClosed,
                      onChanged: (open) => setState(() {
                        _hours[i] = WeeklyHours(
                          day: _hours[i].day,
                          openTime: _hours[i].openTime,
                          closeTime: _hours[i].closeTime,
                          isClosed: !open,
                        );
                      }),
                    ),
                    if (!_hours[i].isClosed)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(
                                  text: _hours[i].openTime,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Open',
                                ),
                                onChanged: (v) => setState(() {
                                  _hours[i] = WeeklyHours(
                                    day: _hours[i].day,
                                    openTime: v,
                                    closeTime: _hours[i].closeTime,
                                    isClosed: false,
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(
                                  text: _hours[i].closeTime,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Close',
                                ),
                                onChanged: (v) => setState(() {
                                  _hours[i] = WeeklyHours(
                                    day: _hours[i].day,
                                    openTime: _hours[i].openTime,
                                    closeTime: v,
                                    isClosed: false,
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      default:
        return ListView(
          children: [
            const Text('Currency'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'INR', label: Text('₹ INR')),
                ButtonSegment(value: 'USD', label: Text('\$ USD')),
              ],
              selected: {_currency},
              onSelectionChanged: (s) => setState(() => _currency = s.first),
            ),
            const SizedBox(height: 24),
            const Text('Delivery types'),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _deliveryTypes.contains('self_pickup'),
              onChanged: (v) => _toggleDelivery('self_pickup', v),
              title: const Text('Self-Pickup'),
            ),
            CheckboxListTile(
              value: _deliveryTypes.contains('home_delivery'),
              onChanged: (v) => _toggleDelivery('home_delivery', v),
              title: const Text('Home Delivery'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.companyPassword,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 12),
            TextField(
              controller: _imageUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Company Image URL (optional)',
                hintText: 'https://example.com/logo.png',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'First Admin Account',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Admin name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Admin email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminPassConfirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        );
    }
  }

  void _toggleDelivery(String type, bool? on) {
    setState(() {
      if (on == true) {
        _deliveryTypes.add(type);
      } else {
        _deliveryTypes.remove(type);
      }
    });
  }

  void _next() => setState(() => _step++);

  // Image upload removed — image URL field is used instead.

  Future<void> _finish() async {
    final companyName = _nameCtrl.text.trim();
    final companyPass = _passwordCtrl.text;
    final adminName = _adminNameCtrl.text.trim();
    final adminEmail = _adminEmailCtrl.text.trim();
    final adminPass = _adminPassCtrl.text;
    final adminPassConfirm = _adminPassConfirmCtrl.text;

    // Basic validation
    if (companyName.isEmpty || companyPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company name and password are required.')),
      );
      return;
    }
    if (adminName.isEmpty || adminEmail.isEmpty || adminPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin name, email, and password are required.'),
        ),
      );
      return;
    }
    if (adminPass != adminPassConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin passwords do not match.')),
      );
      return;
    }
    if (adminPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin password must be at least 6 characters.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      // 1. Create or authenticate Admin Auth user first.
      // This ensures we don't leave orphaned company records if auth fails,
      // and guarantees write permissions for subsequent Firestore/RTDB calls.
      UserCredential userCred;
      try {
        userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPass,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          try {
            userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: adminEmail,
              password: adminPass,
            );
          } on FirebaseAuthException catch (signInError) {
            if (signInError.code == 'invalid-credential' ||
                signInError.code == 'wrong-password') {
              throw FirebaseAuthException(
                code: 'email-already-in-use',
                message:
                    'This email is already registered, but the password provided does not match. Please enter your existing password, sign in via Admin Login, or use a different email.',
              );
            }
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final uid = userCred.user?.uid;
      if (uid == null) {
        throw Exception('Failed to obtain authenticated user ID.');
      }

      // 2. Create Company in Firestore & Realtime Database
      final companyRef =
          FirebaseFirestore.instance.collection('companies').doc();
      final companyId = companyRef.id;

      final company = Company(
        id: companyId,
        name: companyName,
        slug: companyName.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
        companyPassword: companyPass,
        details: _detailsCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        logoUrl: _imageUrlCtrl.text.trim(),
        currency: _currency,
        deliveryTypes: _deliveryTypes.toList(),
        weeklyHours: _hours,
        openingDate: DateTime.now(),
      );

      // Save to Cloud Firestore
      await companyRef.set(company.toMap());

      // Save to Realtime Database
      try {
        await FirebaseDatabase.instance
            .ref('companies/$companyId')
            .set(company.toMap());
      } catch (rtdbErr) {
        debugPrint('Realtime Database company sync: $rtdbErr');
      }

      // 3. Create Admin document in Firestore & Realtime Database
      final admin = Admin(
        id: uid,
        companyId: companyId,
        name: adminName,
        email: adminEmail,
        mobileNumber: '',
        address: _addressCtrl.text.trim(),
      );

      final adminMap = {
        ...admin.toMap(),
        'id': uid,
      };

      // Save to Cloud Firestore in subcollection: companies/{companyId}/admins/{uid}
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('admins')
          .doc(uid)
          .set(adminMap);

      // Save user pointer document to users/{uid} for immediate reload resolution
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'id': uid,
        'role': 'admin',
        'companyId': companyId,
        'email': adminEmail,
        'name': adminName,
      }, SetOptions(merge: true));

      // Save to Realtime Database
      try {
        await FirebaseDatabase.instance
            .ref('companies/$companyId/admins/$uid')
            .set(adminMap);
      } catch (rtdbErr) {
        debugPrint('Realtime Database admin sync: $rtdbErr');
      }

      // 4. Save media link if an image URL was specified
      // User is now authenticated, so media_links rules (auth != null) allow the write!
      final logoUrl = _imageUrlCtrl.text.trim();
      if (logoUrl.isNotEmpty) {
        final media = MediaUrlPayload(
          id: companyId,
          imageUrl: logoUrl,
          videoUrl: '',
          updatedAt: DateTime.now().toIso8601String(),
        );
        try {
          await saveMediaToFirestore(media);
          await saveMediaToRealtimeDatabase(media);
        } catch (mediaErr) {
          debugPrint('Media links sync: $mediaErr');
        }
      }

      // 5. Establish authenticated session
      final appUser = AppUser(
        id: uid,
        companyId: companyId,
        name: adminName,
        email: adminEmail,
        role: 'admin',
      );

      if (!mounted) return;
      context.read<AuthCubit>().setAuthenticatedUser(appUser);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Company "$companyName" registered successfully!'),
        ),
      );

      context.go(AppRoutes.admin);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuthException during onboarding: ${e.code} ${e.message}',
      );
      String userMsg = e.message ?? 'Authentication error occurred.';
      if (e.code == 'weak-password') {
        userMsg = 'Password is too weak. Please use at least 6 characters.';
      } else if (e.code == 'email-already-in-use') {
        userMsg = e.message ??
            'That email is already registered. Please sign in via Admin Login or use a different email.';
      } else if (e.code == 'invalid-email') {
        userMsg = 'Please enter a valid email address.';
      } else if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        userMsg =
            'Invalid credentials. If you already have an account, enter its existing password or sign in via Admin Login.';
      } else if (e.code == 'too-many-requests') {
        userMsg = 'Too many attempts. Please wait a moment and try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMsg)));
      }
    } catch (e, st) {
      debugPrint('Unexpected error during onboarding: $e');
      debugPrint('Stack: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
