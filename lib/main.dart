import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'app/l10n/locale_cubit.dart';
import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/service_locator.dart';
import 'features/auth/auth_cubit.dart';
import 'features/checkout/cart/cart_cubit.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // Firebase initialization
  // ------------------------------------------------------------------
  var firebaseReady = false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    firebaseReady = true;

    // App Check (blocks non-genuine clients). Skip on web (needs reCAPTCHA).
    await _initAppCheck();

    // FCM background handler (works even when the app is terminated).
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (e) {
    debugPrint(
      '!! Firebase is not configured yet — running in MOCK mode.\n'
      '   Run `flutterfire configure` (see SETUP.md). Error: $e',
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

  runApp(Bootstrap(firebaseReady: firebaseReady));
}

Future<void> _initAppCheck() async {
  if (kIsWeb) return; // Web App Check uses reCAPTCHA — see SETUP.md.
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

  @override
  void initState() {
    super.initState();
    _localeCubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return App(
      localeCubit: _localeCubit,
      providers: [
        BlocProvider<LocaleCubit>.value(value: _localeCubit),
        BlocProvider<AuthCubit>.value(value: _authCubit),
        BlocProvider<CartCubit>.value(value: _cartCubit),
      ],
      firebaseReady: widget.firebaseReady,
    );
  }
}
