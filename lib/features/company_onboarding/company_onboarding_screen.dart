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
  final _adminMobileCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();
  final _adminPassConfirmCtrl = TextEditingController();

  // Validation error states - Step 0
  String? _nameError;
  String? _categoryError;
  String? _detailsError;
  String? _addressError;

  // Validation error states - Step 2
  String? _passwordError;
  String? _logoUrlError;
  String? _bannerUrlError;
  String? _profileImageUrlError;
  String? _adminNameError;
  String? _adminEmailError;
  String? _adminMobileError;
  String? _adminPassError;
  String? _adminPassConfirmError;

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email.trim());
  }

  bool _isValidMobile(String mobile) {
    final clean = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    return clean.length == 10;
  }

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
    _adminMobileCtrl.dispose();
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
                    key: Key(
                      _step < 2
                          ? 'onboarding_next_button'
                          : 'onboarding_save_button',
                    ),
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
              key: const Key('company_name_field'),
              controller: _nameCtrl,
              onChanged: (v) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                labelText: '${l10n.companyName} *',
                hintText: AppLocalizations.of(context).eGOmMartExpress,
                prefixIcon: const Icon(Icons.business),
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('store_category_field'),
              controller: _categoryCtrl,
              onChanged: (v) {
                if (_categoryError != null)
                  setState(() => _categoryError = null);
              },
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context).storeCategory} *',
                hintText: AppLocalizations.of(
                  context,
                ).eGGroceryStaplesSupermarketElectronics,
                prefixIcon: const Icon(Icons.category_outlined),
                errorText: _categoryError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('app_subtitle_field'),
              controller: _detailsCtrl,
              maxLines: 2,
              onChanged: (v) {
                if (_detailsError != null) setState(() => _detailsError = null);
              },
              decoration: InputDecoration(
                labelText: '${l10n.appSubtitle} *',
                hintText: AppLocalizations.of(
                  context,
                ).eGFreshOrganicGroceriesDeliveredDaily,
                prefixIcon: const Icon(Icons.description_outlined),
                errorText: _detailsError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('store_address_field'),
              controller: _addressCtrl,
              onChanged: (v) {
                if (_addressError != null) setState(() => _addressError = null);
              },
              decoration: InputDecoration(
                labelText: '${l10n.address} *',
                hintText: AppLocalizations.of(
                  context,
                ).eG12MarketStreetAhmedabad,
                prefixIcon: const Icon(Icons.location_on_outlined),
                errorText: _addressError,
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
              segments: [
                ButtonSegment(
                  value: 'INR',
                  label: Text(AppLocalizations.of(context).inr),
                ),
                ButtonSegment(
                  value: 'USD',
                  label: Text(AppLocalizations.of(context).usd),
                ),
              ],
              selected: {_currency},
              onSelectionChanged: (s) => setState(() => _currency = s.first),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context).deliveryTypes),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('delivery_self_pickup_tile'),
              value: _deliveryTypes.contains('self_pickup'),
              onChanged: (v) => _toggleDelivery('self_pickup', v),
              title: Text(AppLocalizations.of(context).selfPickup2),
            ),
            CheckboxListTile(
              key: const Key('delivery_home_delivery_tile'),
              value: _deliveryTypes.contains('home_delivery'),
              onChanged: (v) => _toggleDelivery('home_delivery', v),
              title: Text(AppLocalizations.of(context).homeDelivery),
            ),
            if (_deliveryTypes.contains('home_delivery')) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('min_order_field'),
                controller: _minOrderCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(
                    context,
                  ).minimumOrderForDelivery(_currency == 'USD' ? '\$' : '₹'),
                  hintText: AppLocalizations.of(context).eG1990ForNoMinimum,
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              key: const Key('company_password_field'),
              controller: _passwordCtrl,
              obscureText: true,
              onChanged: (v) {
                if (_passwordError != null)
                  setState(() => _passwordError = null);
              },
              decoration: InputDecoration(
                labelText: '${l10n.companyPassword} *',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _passwordError,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).companyBrandingImages,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('company_logo_url_field'),
              controller: _logoUrlCtrl,
              keyboardType: TextInputType.url,
              onChanged: (v) {
                if (_logoUrlError != null) setState(() => _logoUrlError = null);
              },
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context).companyLogoUrl} *',
                hintText: AppLocalizations.of(context).httpsExampleComLogoPng,
                prefixIcon: const Icon(Icons.photo_size_select_actual_outlined),
                errorText: _logoUrlError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('company_banner_url_field'),
              controller: _bannerUrlCtrl,
              keyboardType: TextInputType.url,
              onChanged: (v) {
                if (_bannerUrlError != null)
                  setState(() => _bannerUrlError = null);
              },
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context).companyBannerUrl} *',
                hintText: AppLocalizations.of(
                  context,
                ).httpsExampleComStoreBannerJpg,
                prefixIcon: const Icon(Icons.panorama_outlined),
                errorText: _bannerUrlError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('company_profile_image_url_field'),
              controller: _profileImageUrlCtrl,
              keyboardType: TextInputType.url,
              onChanged: (v) {
                if (_profileImageUrlError != null) {
                  setState(() => _profileImageUrlError = null);
                }
              },
              decoration: InputDecoration(
                labelText:
                    '${AppLocalizations.of(context).companyStorefrontProfileImageUrl} *',
                hintText: AppLocalizations.of(
                  context,
                ).httpsExampleComStorefrontPhotoJpg,
                prefixIcon: const Icon(Icons.storefront_outlined),
                errorText: _profileImageUrlError,
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
              key: const Key('admin_name_field'),
              controller: _adminNameCtrl,
              onChanged: (v) {
                if (_adminNameError != null)
                  setState(() => _adminNameError = null);
              },
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context).adminName} *',
                prefixIcon: const Icon(Icons.person),
                errorText: _adminNameError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin_email_field'),
              controller: _adminEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) {
                if (_adminEmailError != null)
                  setState(() => _adminEmailError = null);
              },
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context).adminEmail} *',
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: _adminEmailError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin_mobile_field'),
              controller: _adminMobileCtrl,
              keyboardType: TextInputType.phone,
              onChanged: (v) {
                if (_adminMobileError != null) {
                  setState(() => _adminMobileError = null);
                }
              },
              decoration: InputDecoration(
                labelText: '${l10n.mobileNumber} *',
                hintText: 'e.g. 9876543210',
                prefixIcon: const Icon(Icons.phone_outlined),
                errorText: _adminMobileError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin_password_field'),
              controller: _adminPassCtrl,
              obscureText: true,
              onChanged: (v) {
                if (_adminPassError != null)
                  setState(() => _adminPassError = null);
              },
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context).password} *',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _adminPassError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('admin_password_confirm_field'),
              controller: _adminPassConfirmCtrl,
              obscureText: true,
              onChanged: (v) {
                if (_adminPassConfirmError != null) {
                  setState(() => _adminPassConfirmError = null);
                }
              },
              decoration: InputDecoration(
                labelText: '${AppLocalizations.of(context).confirmPassword} *',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _adminPassConfirmError,
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

  void _next() {
    if (_step == 0) {
      final name = _nameCtrl.text.trim();
      final category = _categoryCtrl.text.trim();
      final details = _detailsCtrl.text.trim();
      final address = _addressCtrl.text.trim();

      bool hasError = false;
      setState(() {
        if (name.isEmpty) {
          _nameError = 'Company name is required';
          hasError = true;
        } else {
          _nameError = null;
        }

        if (category.isEmpty) {
          _categoryError = 'Store category is required';
          hasError = true;
        } else {
          _categoryError = null;
        }

        if (details.isEmpty) {
          _detailsError = 'Company subtitle/details are required';
          hasError = true;
        } else {
          _detailsError = null;
        }

        if (address.isEmpty) {
          _addressError = 'Address is required';
          hasError = true;
        } else {
          _addressError = null;
        }
      });

      if (hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required company fields'),
          ),
        );
        return;
      }
    }

    setState(() => _step++);
  }

  // Image upload removed — image URL field is used instead.

  Future<void> _finish() async {
    if (_deliveryTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one delivery option'),
        ),
      );
      return;
    }

    final companyName = _nameCtrl.text.trim();
    final companyPass = _passwordCtrl.text;
    final logoUrl = _logoUrlCtrl.text.trim();
    final bannerUrl = _bannerUrlCtrl.text.trim();
    final profileImageUrl = _profileImageUrlCtrl.text.trim();

    final adminName = _adminNameCtrl.text.trim();
    final adminEmail = _adminEmailCtrl.text.trim();
    final adminMobile = _adminMobileCtrl.text.trim();
    final adminPass = _adminPassCtrl.text;
    final adminPassConfirm = _adminPassConfirmCtrl.text;

    // Validate all Step 2 fields (Company security, branding, and Admin account)
    bool hasError = false;
    setState(() {
      if (companyPass.isEmpty) {
        _passwordError = 'Company password is required';
        hasError = true;
      } else if (companyPass.length < 6) {
        _passwordError = 'Company password must be at least 6 characters';
        hasError = true;
      } else {
        _passwordError = null;
      }

      if (logoUrl.isEmpty) {
        _logoUrlError = 'Company logo URL is required';
        hasError = true;
      } else if (!logoUrl.startsWith('http://') &&
          !logoUrl.startsWith('https://')) {
        _logoUrlError = 'Please enter a valid HTTP or HTTPS URL';
        hasError = true;
      } else {
        _logoUrlError = null;
      }

      if (bannerUrl.isEmpty) {
        _bannerUrlError = 'Company banner URL is required';
        hasError = true;
      } else if (!bannerUrl.startsWith('http://') &&
          !bannerUrl.startsWith('https://')) {
        _bannerUrlError = 'Please enter a valid HTTP or HTTPS URL';
        hasError = true;
      } else {
        _bannerUrlError = null;
      }

      if (profileImageUrl.isEmpty) {
        _profileImageUrlError = 'Storefront profile image URL is required';
        hasError = true;
      } else if (!profileImageUrl.startsWith('http://') &&
          !profileImageUrl.startsWith('https://')) {
        _profileImageUrlError = 'Please enter a valid HTTP or HTTPS URL';
        hasError = true;
      } else {
        _profileImageUrlError = null;
      }

      if (adminName.isEmpty) {
        _adminNameError = 'Admin name is required';
        hasError = true;
      } else {
        _adminNameError = null;
      }

      if (adminEmail.isEmpty) {
        _adminEmailError = 'Admin email is required';
        hasError = true;
      } else if (!_isValidEmail(adminEmail)) {
        _adminEmailError = 'Please enter a valid email address';
        hasError = true;
      } else {
        _adminEmailError = null;
      }

      if (adminMobile.isEmpty) {
        _adminMobileError = 'Admin mobile number is required';
        hasError = true;
      } else if (!_isValidMobile(adminMobile)) {
        _adminMobileError = 'Please enter a valid 10-digit mobile number';
        hasError = true;
      } else {
        _adminMobileError = null;
      }

      if (adminPass.isEmpty) {
        _adminPassError = 'Admin password is required';
        hasError = true;
      } else if (adminPass.length < 6) {
        _adminPassError = 'Admin password must be at least 6 characters';
        hasError = true;
      } else {
        _adminPassError = null;
      }

      if (adminPassConfirm.isEmpty) {
        _adminPassConfirmError = 'Please confirm your password';
        hasError = true;
      } else if (adminPass != adminPassConfirm) {
        _adminPassConfirmError = 'Passwords do not match';
        hasError = true;
      } else {
        _adminPassConfirmError = null;
      }
    });

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields correctly'),
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context);
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
                message: l10n
                    .thisEmailIsAlreadyRegisteredButThePasswordProvidedDoesNotMatchPleaseEnterYourExistingPasswordSignInViaAdminLoginOrUseADifferentEmail,
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
        throw Exception(l10n.failedToObtainAuthenticatedUserId);
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
        mobileNumber: adminMobile,
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
        'mobileNumber': adminMobile,
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
        companyName: companyName,
        name: adminName,
        email: adminEmail,
        mobileNumber: adminMobile,
        role: 'admin',
      );

      if (!mounted) return;
      context.read<AuthCubit>().setAuthenticatedUser(appUser);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.companyRegisteredSuccessfully(companyName)),
        ),
      );

      context.go(AppRoutes.admin);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuthException during onboarding: ${e.code} ${e.message}',
      );
      String userMsg = e.message ?? l10n.authenticationErrorOccurred;
      if (e.code == 'weak-password') {
        userMsg = l10n.passwordIsTooWeakPleaseUseAtLeast6Characters;
      } else if (e.code == 'email-already-in-use') {
        userMsg =
            e.message ??
            l10n.thatEmailIsAlreadyRegisteredPleaseSignInViaAdminLoginOrUseADifferentEmail;
      } else if (e.code == 'invalid-email') {
        userMsg = l10n.pleaseEnterAValidEmailAddress;
      } else if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        userMsg = l10n
            .invalidCredentialsIfYouAlreadyHaveAnAccountEnterItsExistingPasswordOrSignInViaAdminLogin;
      } else if (e.code == 'too-many-requests') {
        userMsg = l10n.tooManyAttemptsPleaseWaitAMomentAndTryAgain;
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
        ).showSnackBar(SnackBar(content: Text(l10n.error(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
