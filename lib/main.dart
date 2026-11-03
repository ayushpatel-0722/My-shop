import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'app/l10n/locale_cubit.dart';
import 'core/cache/app_images.dart';
import 'core/cache/cache_consent.dart';
import 'core/cache/cache_consent_controller.dart';
import 'core/cache/firestore_cache.dart';
import 'core/cache/shared_streams.dart';
import 'core/config/app_config.dart';
import 'core/config/environment.dart';
import 'core/services/auth_session.dart';
import 'core/services/notification_service.dart';
import 'core/services/service_locator.dart';
import 'features/auth/auth_cubit.dart';
import 'features/checkout/cart/cart_cubit.dart';
import 'features/checkout/cart/wishlist_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // Firebase initialization
  // ------------------------------------------------------------------
  var firebaseReady = false;
  try {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: EnvironmentConfig.firebaseOptions,
        );
      }
    } catch (initErr) {
      if (initErr.toString().contains('duplicate-app') ||
          Firebase.apps.isNotEmpty) {
        debugPrint('Firebase default app already initialized.');
      } else {
        rethrow;
      }
    }
    firebaseReady = true;
    debugPrint(
      '\u2705 Firebase initialized for ${EnvironmentConfig.current.name.toUpperCase()} environment.',
    );

    // App Check (blocks non-genuine clients). Skip on web (needs reCAPTCHA).
    try {
      await _initAppCheck();
    } catch (appCheckErr) {
      debugPrint('App Check init warning: $appCheckErr');
    }

    // FCM background handler (works even when the app is terminated).
    if (!kIsWeb) {
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (fcmErr) {
        debugPrint('FCM background handler setup warning: $fcmErr');
      }
    }
  } catch (e) {
    debugPrint(
      '!! Firebase is not configured yet — running in MOCK mode.\n'
      '   Run `flutterfire configure` (see README.md). Error: $e',
    );
    firebaseReady = false;
  }

  // ------------------------------------------------------------------
  // Dependency wiring
  // ------------------------------------------------------------------
  ServiceLocator.instance.init(firebaseReady: firebaseReady);
  if (firebaseReady) {
    try {
      await ServiceLocator.instance.remoteConfigService?.init().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('RemoteConfig init timed out, using defaults.');
        },
      );
    } catch (e) {
      debugPrint('RemoteConfig init error: $e');
    }
  }

  // ------------------------------------------------------------------
  // Caching: Firestore's bounded on-device cache, the image disk cache and,
  // on the web, the one-time storage consent. The cache is configured before
  // the first read; on the web that waits for the shopper's answer.
  // ------------------------------------------------------------------
  AppImages.init();
  var storedConsent = CacheConsent.undecided;
  if (firebaseReady) {
    try {
      await FirestoreCache.clearIfPending(FirebaseFirestore.instance);
    } catch (e) {
      debugPrint('Cache clear skipped: $e');
    }
  }
  if (kIsWeb) storedConsent = await CacheConsentStore().read();

  // The app starts right away. On the web, a first-time visitor is asked over
  // the running app (see CacheConsentPrompt); until answered nothing is kept
  // on disk. Everyone else gets their stored answer applied now.
  final consentController = CacheConsentController(
    initial: storedConsent,
    isWeb: kIsWeb,
    onApply: (consent) {
      if (firebaseReady) {
        FirestoreCache.apply(FirebaseFirestore.instance, consent: consent);
      }
    },
  );
  CacheConsentController.instance = consentController;
  consentController.start();

  runApp(Bootstrap(firebaseReady: firebaseReady));
}

Future<void> _initAppCheck() async {
  if (kIsWeb) return; // Web App Check uses reCAPTCHA — see README.md.
  try {
    if (defaultTargetPlatform == TargetPlatform.android &&
        AppConfig.appCheckDebugTokenAndroid.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        // ignore: deprecated_member_use
        androidProvider: AndroidProvider.debug,
      );
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        AppConfig.appCheckDebugTokenApple.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        // ignore: deprecated_member_use
        appleProvider: AppleProvider.debug,
      );
      return;
    }
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use
      appleProvider: AppleProvider.appAttest,
    );
  } catch (e) {
    debugPrint('App Check activation skipped: $e');
  }
}

class Bootstrap extends StatefulWidget {
  final bool firebaseReady;
  const Bootstrap({super.key, required this.firebaseReady});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  final LocaleCubit _localeCubit = LocaleCubit();
  final AuthCubit _authCubit = AuthCubit();
  final CartCubit _cartCubit = CartCubit();
  final WishlistCubit _wishlistCubit = WishlistCubit();

  @override
  void initState() {
    super.initState();
    _localeCubit.load();
    // Favourites belong to whoever is signed in: follow the session so a
    // sign-out or an account switch never shows the previous user's list.
    AuthSession.instance.addListener(_syncFavorites);
    AuthSession.instance.addListener(_onAccountChanged);
    _syncFavorites();
  }

  String? _lastUserId = AuthSession.currentUser?.id;

  void _syncFavorites() => _wishlistCubit.bindUser(AuthSession.currentUser?.id);

  /// Private data must not outlive the account it belongs to: when a signed-in
  /// account signs out (or another signs in), the in-memory shared queries are
  /// dropped and Firestore's on-device cache is cleared at the next start.
  void _onAccountChanged() {
    final id = AuthSession.currentUser?.id;
    final previous = _lastUserId;
    if (id == previous) return;
    _lastUserId = id;
    if (previous != null) {
      SharedStreams.instance.clear();
      FirestoreCache.markForClearing();
    }
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_syncFavorites);
    AuthSession.instance.removeListener(_onAccountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return App(
      localeCubit: _localeCubit,
      providers: [
        BlocProvider<LocaleCubit>.value(value: _localeCubit),
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<CartCubit>.value(value: _cartCubit),
        BlocProvider<WishlistCubit>.value(value: _wishlistCubit),
      ],
      firebaseReady: widget.firebaseReady,
    );
  }
}
