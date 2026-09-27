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
  final _categoryCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _bannerUrlCtrl = TextEditingController();
  final _profileImageUrlCtrl = TextEditingController();
  final _minOrderCtrl = TextEditingController();
  String _currency = 'INR';
  final List<WeeklyHours> _hours = Company.defaultWeek();
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
    _categoryCtrl.dispose();
    _detailsCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _logoUrlCtrl.dispose();
    _bannerUrlCtrl.dispose();
    _profileImageUrlCtrl.dispose();
    _minOrderCtrl.dispose();
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
                    onPressed: _step < 2 ? _next : (_busy ? null : _finish),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(_step < 2 ? l10n.next : l10n.save),
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
                hintText: AppLocalizations.of(context).eGOmMartExpress,
                prefixIcon: const Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).storeCategory,
                hintText: AppLocalizations.of(context).eGGroceryStaplesSupermarketElectronics,
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _detailsCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.appSubtitle,
                hintText: AppLocalizations.of(context).eGFreshOrganicGroceriesDeliveredDaily,
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: l10n.address,
                hintText: AppLocalizations.of(context).eG12MarketStreetAhmedabad,
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
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context).open,
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
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context).close,
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
            Text(AppLocalizations.of(context).currency),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'INR', label: Text(AppLocalizations.of(context).inr)),
                ButtonSegment(value: 'USD', label: Text(AppLocalizations.of(context).usd)),
              ],
              selected: {_currency},
              onSelectionChanged: (s) => setState(() => _currency = s.first),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context).deliveryTypes),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _deliveryTypes.contains('self_pickup'),
              onChanged: (v) => _toggleDelivery('self_pickup', v),
              title: Text(AppLocalizations.of(context).selfPickup2),
            ),
            CheckboxListTile(
              value: _deliveryTypes.contains('home_delivery'),
              onChanged: (v) => _toggleDelivery('home_delivery', v),
              title: Text(AppLocalizations.of(context).homeDelivery),
            ),
            if (_deliveryTypes.contains('home_delivery')) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _minOrderCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context).minimumOrderForDelivery('${_currency == 'USD' ? '\$' : '₹'}'),
                  hintText: AppLocalizations.of(context).eG1990ForNoMinimum,
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
            ],
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
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).companyBrandingImages,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _logoUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).companyLogoUrl,
                hintText: AppLocalizations.of(context).httpsExampleComLogoPng,
                prefixIcon: Icon(Icons.photo_size_select_actual_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bannerUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).companyBannerUrl,
                hintText: AppLocalizations.of(context).httpsExampleComStoreBannerJpg,
                prefixIcon: Icon(Icons.panorama_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _profileImageUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).companyStorefrontProfileImageUrl,
                hintText: AppLocalizations.of(context).httpsExampleComStorefrontPhotoJpg,
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).firstAdminAccount,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminNameCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).adminName,
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).adminEmail,
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminPassCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).password,
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminPassConfirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).confirmPassword,
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
        SnackBar(
          content: Text(AppLocalizations.of(context).companyNameAndPasswordAreRequired),
        ),
      );
      return;
    }
    if (adminName.isEmpty || adminEmail.isEmpty || adminPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).adminNameEmailAndPasswordAreRequired),
        ),
      );
      return;
    }
    if (adminPass != adminPassConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).adminPasswordsDoNotMatch)),
      );
      return;
    }
    if (adminPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).adminPasswordMustBeAtLeast6Characters),
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
                    AppLocalizations.of(context).thisEmailIsAlreadyRegisteredButThePasswordProvidedDoesNotMatchPleaseEnterYourExistingPasswordSignInViaAdminLoginOrUseADifferentEmail,
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
        throw Exception(AppLocalizations.of(context).failedToObtainAuthenticatedUserId);
      }

      // 2. Create Company in Firestore & Realtime Database
      final companyRef = FirebaseFirestore.instance
          .collection('companies')
          .doc();
      final companyId = companyRef.id;

      final company = Company(
        id: companyId,
        name: companyName,
        slug: companyName.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
        companyPassword: companyPass,
        details: _detailsCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        logoUrl: _logoUrlCtrl.text.trim(),
        bannerUrl: _bannerUrlCtrl.text.trim(),
        profileImageUrl: _profileImageUrlCtrl.text.trim(),
        currency: _currency,
        deliveryTypes: _deliveryTypes.toList(),
        weeklyHours: _hours,
        openingDate: DateTime.now(),
        minOrderAmount: double.tryParse(_minOrderCtrl.text.trim()) ?? 0.0,
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

      final adminMap = {...admin.toMap(), 'id': uid};

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
      final logoUrl = _logoUrlCtrl.text.trim();
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
          content: Text(AppLocalizations.of(context).companyRegisteredSuccessfully('${companyName}')),
        ),
      );

      context.go(AppRoutes.admin);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuthException during onboarding: ${e.code} ${e.message}',
      );
      String userMsg = e.message ?? AppLocalizations.of(context).authenticationErrorOccurred;
      if (e.code == 'weak-password') {
        userMsg = AppLocalizations.of(context).passwordIsTooWeakPleaseUseAtLeast6Characters;
      } else if (e.code == 'email-already-in-use') {
        userMsg =
            e.message ??
            AppLocalizations.of(context).thatEmailIsAlreadyRegisteredPleaseSignInViaAdminLoginOrUseADifferentEmail;
      } else if (e.code == 'invalid-email') {
        userMsg = AppLocalizations.of(context).pleaseEnterAValidEmailAddress;
      } else if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        userMsg =
            AppLocalizations.of(context).invalidCredentialsIfYouAlreadyHaveAnAccountEnterItsExistingPasswordOrSignInViaAdminLogin;
      } else if (e.code == 'too-many-requests') {
        userMsg = AppLocalizations.of(context).tooManyAttemptsPleaseWaitAMomentAndTryAgain;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).error('${e.toString()}'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
