// Firebase options for the **PROD** environment.
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  TODO: Replace ALL placeholder values below with real PROD       ║
// ║  Firebase project credentials.                                   ║
// ║                                                                  ║
// ║  Steps:                                                          ║
// ║  1. Create a new Firebase project for PROD in the Firebase       ║
// ║     Console (https://console.firebase.google.com).               ║
// ║  2. Register Android/iOS/Web apps in the PROD project.           ║
// ║  3. Run: flutterfire configure --project=<PROD_PROJECT_ID>       ║
// ║     and copy the generated values here.                          ║
// ║  4. Download the PROD google-services.json and place it in       ║
// ║     android/app/src/prod/google-services.json                    ║
// ╚═══════════════════════════════════════════════════════════════════╝
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// PROD [FirebaseOptions] — points to the **production** Firebase project.
///
/// **WARNING**: All values below are placeholders. The app will NOT connect
/// to any real Firebase project until they are replaced.
class ProdFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'ProdFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'ProdFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Replace with real PROD Firebase Web credentials.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PROD-WEB-API-KEY',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'myshop-prod-REPLACE-ME',
    authDomain: 'myshop-prod-REPLACE-ME.firebaseapp.com',
    databaseURL: 'https://myshop-prod-REPLACE-ME-default-rtdb.firebaseio.com',
    storageBucket: 'myshop-prod-REPLACE-ME.firebasestorage.app',
  );

  // TODO: Replace with real PROD Firebase Android credentials.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PROD-ANDROID-API-KEY',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'myshop-prod-REPLACE-ME',
    databaseURL: 'https://myshop-prod-REPLACE-ME-default-rtdb.firebaseio.com',
    storageBucket: 'myshop-prod-REPLACE-ME.firebasestorage.app',
  );

  // TODO: Replace with real PROD Firebase iOS credentials.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PROD-IOS-API-KEY',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'myshop-prod-REPLACE-ME',
    databaseURL: 'https://myshop-prod-REPLACE-ME-default-rtdb.firebaseio.com',
    storageBucket: 'myshop-prod-REPLACE-ME.firebasestorage.app',
    iosBundleId: 'com.example.myshop',
  );

  // TODO: Replace with real PROD Firebase macOS credentials.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'PROD-MACOS-API-KEY',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'myshop-prod-REPLACE-ME',
    databaseURL: 'https://myshop-prod-REPLACE-ME-default-rtdb.firebaseio.com',
    storageBucket: 'myshop-prod-REPLACE-ME.firebasestorage.app',
    iosBundleId: 'com.example.myshop',
  );

  // TODO: Replace with real PROD Firebase Windows credentials.
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'PROD-WINDOWS-API-KEY',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'myshop-prod-REPLACE-ME',
    authDomain: 'myshop-prod-REPLACE-ME.firebaseapp.com',
    databaseURL: 'https://myshop-prod-REPLACE-ME-default-rtdb.firebaseio.com',
    storageBucket: 'myshop-prod-REPLACE-ME.firebasestorage.app',
  );
}
