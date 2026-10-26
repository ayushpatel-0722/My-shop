import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/customer.dart';
import '../auth_cubit.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

/// Multi-step Bottom Sheet that handles guest authentication:
/// 1. Google Sign-In
/// 2. Mobile number capture (No OTP - direct continue)
/// 3. Structured address capture (House No, Area/Landmark, Pincode)
/// 4. Auto-resumes caller's action via [onAuthenticated]
class AuthBottomSheet extends StatefulWidget {
  final VoidCallback? onAuthenticated;
  final bool requireAddress;
  final String? message;
  final String? title;

  const AuthBottomSheet({
    super.key,
    this.onAuthenticated,
    this.requireAddress = false,
    this.message,
    this.title,
  });

  static Future<bool> show(
    BuildContext context, {
    VoidCallback? onAuthenticated,
    bool requireAddress = false,
    String? message,
    String? title,
  }) async {
    AuthCubit? authCubit;
    try {
      authCubit = context.read<AuthCubit>();
    } catch (_) {}

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheet = AuthBottomSheet(
          onAuthenticated: onAuthenticated,
          requireAddress: requireAddress,
          message: message,
          title: title,
        );
        if (authCubit != null) {
          return BlocProvider<AuthCubit>.value(value: authCubit, child: sheet);
        }
        return sheet;
      },
    );
    return result ?? false;
  }

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

enum _AuthStep { googleSignIn, mobileInput, addressInput }

class _AuthBottomSheetState extends State<AuthBottomSheet> {
  _AuthStep _currentStep = _AuthStep.googleSignIn;
  bool _busy = false;

  // Mobile Step Controllers
  final _mobileCtrl = TextEditingController();
  final _mobileFormKey = GlobalKey<FormState>();

  // Address Step Controllers
  final _houseNoCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _addressFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _houseNoCtrl.dispose();
    _streetCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  void _finishAndClose() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
    widget.onAuthenticated?.call();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _busy = true);
    final authCubit = context.read<AuthCubit>();
    final ok = await authCubit.signInWithGoogle(context);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).signInFailedPleaseTryAgain,
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final user = authCubit.currentUser;
    if (user == null) return;

    // Check if mobile number is missing
    if (user.mobileNumber.trim().isEmpty) {
      setState(() => _currentStep = _AuthStep.mobileInput);
      return;
    }

    // Check if address is missing or required
    if (user.addresses.isEmpty || widget.requireAddress) {
      setState(() => _currentStep = _AuthStep.addressInput);
      return;
    }

    _finishAndClose();
  }

  Future<void> _handleSaveMobile() async {
    if (_mobileFormKey.currentState?.validate() != true) return;
    setState(() => _busy = true);

    final raw = _mobileCtrl.text.trim();
    final authCubit = context.read<AuthCubit>();
    final ok = await authCubit.updateUserMobile(raw);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).failedToSaveMobileNumberTryAgain,
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final user = authCubit.currentUser;
    // Check if address is missing
    if (user != null && (user.addresses.isEmpty || widget.requireAddress)) {
      setState(() => _currentStep = _AuthStep.addressInput);
      return;
    }

    _finishAndClose();
  }

  Future<void> _handleSaveAddress() async {
    if (_addressFormKey.currentState?.validate() != true) return;
    setState(() => _busy = true);

    final address = AddressEntry(
      houseNo: _houseNoCtrl.text.trim(),
      address: _streetCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      isDefault: true,
      label: AppLocalizations.of(context).home,
    );

    final authCubit = context.read<AuthCubit>();
    final ok = await authCubit.saveUserAddress(address);

    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).failedToSaveAddressTryAgain,
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _finishAndClose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Animated Step Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _buildCurrentStep(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_currentStep) {
      case _AuthStep.googleSignIn:
        return _buildGoogleSignInStep(context);
      case _AuthStep.mobileInput:
        return _buildMobileStep(context);
      case _AuthStep.addressInput:
        return _buildAddressStep(context);
    }
  }

  // ---------------------------------------------------------------------------
  // Step 1: Continue with Google
  // ---------------------------------------------------------------------------
  Widget _buildGoogleSignInStep(BuildContext context) {
    return Column(
      key: const ValueKey('google_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5247).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFFFF5247),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title ??
                        AppLocalizations.of(context).welcomeToBazaar,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.message ??
                        AppLocalizations.of(
                          context,
                        ).signInToPlaceOrdersSaveCartApplyVouchers,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: Colors.grey.shade300, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: Colors.white,
          ),
          onPressed: _busy ? null : _handleGoogleSignIn,
          child: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFFF5247),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 30,
                      color: Color(0xFFEA4335),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).continueWithGoogle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            AppLocalizations.of(
              context,
            ).byContinuingYouAgreeToOurTermsPrivacyPolicy,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Enter Mobile Number (No OTP)
  // ---------------------------------------------------------------------------
  Widget _buildMobileStep(BuildContext context) {
    return Form(
      key: _mobileFormKey,
      child: Column(
        key: const ValueKey('mobile_step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5247).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: Color(0xFFFF5247),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).enterMobileNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).forDeliveryTrackingOrderSmsUpdates,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).mobileNumber,
              hintText: '9876543210',
              prefixText: '+91  ',
              prefixIcon: const Icon(Icons.phone),
              helperText: AppLocalizations.of(
                context,
              ).enter10DigitIndianMobileNumber,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            validator: (v) {
              final raw = (v ?? '').replaceAll(RegExp(r'[\s\-().]+'), '');
              final digits = raw.startsWith('+91')
                  ? raw.substring(3)
                  : raw.startsWith('91') && raw.length == 12
                  ? raw.substring(2)
                  : raw.startsWith('0')
                  ? raw.substring(1)
                  : raw;
              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                return AppLocalizations.of(
                  context,
                ).enterAValid10DigitMobileNumber;
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5247),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _busy ? null : _handleSaveMobile,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    AppLocalizations.of(context).continueLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Structured Address Entry
  // ---------------------------------------------------------------------------
  Widget _buildAddressStep(BuildContext context) {
    return Form(
      key: _addressFormKey,
      child: Column(
        key: const ValueKey('address_step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D38D9).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF3D38D9),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).deliveryAddress,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(
                        context,
                      ).enterYourAddressForAccurateDelivery,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _houseNoCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).houseFlatFloorNo,
              hintText: AppLocalizations.of(context).eGFlat302BuildingA,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppLocalizations.of(context).houseFlatNumberIsRequired
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _streetCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).streetAreaLandmark,
              hintText: AppLocalizations.of(
                context,
              ).eGGreenValleyRoadNearCityMall,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppLocalizations.of(context).streetOrAreaIsRequired
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pincodeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).pincode,
              hintText: '380001',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (v) {
              final val = (v ?? '').trim();
              if (val.isEmpty) {
                return AppLocalizations.of(context).pincodeIsRequired;
              }
              if (val.length != 6 || int.tryParse(val) == null) {
                return AppLocalizations.of(context).enterAValid6DigitPincode;
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5247),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _busy ? null : _handleSaveAddress,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    AppLocalizations.of(context).saveAddressContinue,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
