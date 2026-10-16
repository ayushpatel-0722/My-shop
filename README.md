# myshop

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


# Flutter Project: UAT & PROD Flavors with Separate Firebase Projects

## Objective

I have an existing Flutter project that is currently connected to **one Firebase project**.

I want to convert the existing Firebase connection into the **UAT environment** and then add a completely separate **PROD Firebase project connection**.

The final Flutter project must support two flavors/environments:

- **UAT** → Existing Firebase project connection
- **PROD** → New Firebase project connection, which is NOT connected yet

The project should be properly structured so that developers can easily run, test, build, and release either UAT or PROD without manually changing Firebase configuration files.

---

# 1. Current Project Situation

The existing Flutter project already has Firebase integration.

The current Firebase project is the **UAT Firebase project**.

Do NOT remove or break the existing Firebase functionality.

Instead:

```text
Existing Firebase Connection
        ↓
Convert/organize as
        ↓
UAT Firebase Environment
```

All existing Firebase functionality must continue working with the UAT Firebase project.

The PROD Firebase project does not currently exist in the Flutter project configuration and must NOT accidentally use the UAT Firebase configuration.

---

# 2. Required Final Environment Structure

Create two Flutter flavors:

```text
uat
prod
```

Environment mapping:

```text
┌──────────────────────┐
│ Flutter UAT Flavor   │
│                      │
│ Existing Firebase    │
│ Project              │
└──────────────────────┘


┌──────────────────────┐
│ Flutter PROD Flavor  │
│                      │
│ New PROD Firebase    │
│ Project              │
└──────────────────────┘
```

The final configuration should behave like:

```text
flutter run --flavor uat
        ↓
UAT Firebase


flutter run --flavor prod
        ↓
PROD Firebase
```

Build commands should also be available:

```bash
flutter build apk --flavor uat
flutter build apk --flavor prod

flutter build appbundle --flavor uat
flutter build appbundle --flavor prod
```

---

# 3. Firebase Environment Configuration

Use separate Firebase configuration for each flavor.

Expected structure:

```text
project/
│
├── android/
│   └── app/
│       ├── src/
│       │   ├── main/
│       │   ├── uat/
│       │   │   └── google-services.json
│       │   └── prod/
│       │       └── google-services.json
│       │
│       └── build.gradle / build.gradle.kts
│
├── ios/
│   └── Runner/
│       ├── GoogleService-Info-UAT.plist
│       └── GoogleService-Info-PROD.plist
│
├── lib/
│   ├── config/
│   │   ├── environment.dart
│   │   ├── uat_config.dart
│   │   └── prod_config.dart
│   │
│   └── firebase/
│       ├── firebase_options_uat.dart
│       └── firebase_options_prod.dart
│
└── ...
```

Adapt this structure to the existing project instead of unnecessarily restructuring unrelated files.

---

# 4. Firebase Options

Generate/use separate Firebase options for each environment.

For example:

```text
firebase_options_uat.dart
firebase_options_prod.dart
```

UAT must contain the configuration for the existing Firebase project.

PROD must contain the configuration for the new PROD Firebase project.

Do NOT copy the UAT Firebase configuration into PROD.

Do NOT use the same Firebase project ID for both environments.

The PROD configuration should remain clearly separated.

---

# 5. Environment Configuration

Create a centralized environment configuration.

For example:

```dart
enum AppEnvironment {
  uat,
  prod,
}
```

Then create an environment configuration that identifies:

```text
Environment
Firebase project
API/base URL if required
App name
Debug/release behavior
Other environment-specific settings
```

Example concept:

```dart
class AppConfig {
  final AppEnvironment environment;

  const AppConfig({
    required this.environment,
  });

  bool get isUat => environment == AppEnvironment.uat;
  bool get isProd => environment == AppEnvironment.prod;
}
```

Do not hard-code UAT/PROD checks throughout the application.

Keep environment-specific configuration centralized.

---

# 6. Firebase Initialization

Update Firebase initialization so the correct Firebase configuration is selected according to the flavor.

The application should initialize:

```text
UAT flavor
    ↓
UAT FirebaseOptions
    ↓
Firebase.initializeApp()
```

and:

```text
PROD flavor
    ↓
PROD FirebaseOptions
    ↓
Firebase.initializeApp()
```

Ensure all Firebase services use the selected Firebase project:

- Firebase Core
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging
- Firebase Remote Config
- Firebase Functions
- Firebase App Check
- Crashlytics
- Any other Firebase service already used in the project

Do not leave any Firebase service accidentally pointing to UAT when running PROD.

---

# 7. Android Flavor Configuration

Create proper Android product flavors:

```text
uat
prod
```

Configure them in the existing Android Gradle configuration.

Expected concept:

```gradle
flavorDimensions "environment"

productFlavors {
    uat {
        dimension "environment"
    }

    prod {
        dimension "environment"
    }
}
```

Use the project's existing Gradle/Kotlin structure and syntax.

Do not blindly replace the existing Gradle configuration.

Preserve the current:

- compile SDK
- target SDK
- min SDK
- Kotlin version
- Gradle version
- plugins
- dependencies
- signing configuration
- Firebase dependencies

Only add the required flavor configuration.

---

# 8. Firebase Android Files

Configure Firebase files separately:

```text
android/app/src/uat/google-services.json
android/app/src/prod/google-services.json
```

The existing Firebase `google-services.json` should become the UAT configuration.

The new PROD Firebase `google-services.json` must be added only when the PROD Firebase project configuration is available.

Important:

```text
UAT:
android/app/src/uat/google-services.json
        ↓
Existing Firebase project


PROD:
android/app/src/prod/google-services.json
        ↓
New PROD Firebase project
```

Do not overwrite the UAT configuration with PROD configuration.

---

# 9. iOS Configuration

If the project supports iOS, configure equivalent UAT and PROD Firebase environments.

Use separate Firebase plist files:

```text
ios/Runner/GoogleService-Info-UAT.plist
ios/Runner/GoogleService-Info-PROD.plist
```

Configure the iOS schemes/configurations appropriately:

```text
UAT
PROD
```

The iOS UAT build must use the existing UAT Firebase project.

The iOS PROD build must use the PROD Firebase project.

If iOS is not currently configured in the project, do not introduce unnecessary iOS changes. Document what needs to be done later.

---

# 10. App IDs / Bundle IDs

Use separate application identifiers where appropriate so UAT and PROD applications can coexist on the same device.

Recommended:

```text
com.company.app.uat
com.company.app
```

or follow the existing project's actual package/bundle ID.

For example:

```text
UAT:
com.example.myapp.uat

PROD:
com.example.myapp
```

Do not arbitrarily change the production package name if the existing production package ID is already configured.

The PROD package/bundle ID should remain suitable for Play Store/App Store release.

---

# 11. App Names

Make the UAT application clearly identifiable.

For example:

```text
UAT:
My App UAT

PROD:
My App
```

This prevents developers/testers from accidentally confusing UAT and PROD applications.

Do not change the production app name unnecessarily.

---

# 12. Main Entry Point

Configure flavor-specific startup cleanly.

Possible structure:

```text
lib/
│
├── main.dart
├── main_uat.dart
└── main_prod.dart
```

or another clean approach if better suited to the existing project.

Expected behavior:

```text
main_uat.dart
    ↓
UAT configuration
    ↓
UAT Firebase


main_prod.dart
    ↓
PROD configuration
    ↓
PROD Firebase
```

Avoid duplicating the complete application startup code.

Use shared initialization where possible.

For example:

```text
main_uat.dart
main_prod.dart
       ↓
shared bootstrap
       ↓
App
```

---

# 13. Recommended Project Structure

After implementation, keep the project clean and scalable.

Recommended structure:

```text
lib/
│
├── main.dart
├── main_uat.dart
├── main_prod.dart
│
├── config/
│   ├── environment.dart
│   ├── uat_config.dart
│   └── prod_config.dart
│
├── firebase/
│   ├── firebase_options_uat.dart
│   └── firebase_options_prod.dart
│
├── core/
│   ├── constants/
│   ├── services/
│   ├── network/
│   ├── database/
│   └── utils/
│
├── features/
│   └── ...
│
└── ...
```

Android:

```text
android/
└── app/
    ├── src/
    │   ├── main/
    │   ├── uat/
    │   │   └── google-services.json
    │   └── prod/
    │       └── google-services.json
    │
    └── build.gradle
```

If the existing project already follows a different architecture, preserve that architecture and only introduce the required environment-specific directories.

---

# 14. Firebase CLI / FlutterFire

Use FlutterFire CLI where appropriate.

The existing Firebase project should be configured as UAT.

Generate the PROD configuration separately when the PROD Firebase project credentials/configuration are provided.

Do not overwrite UAT configuration while generating PROD configuration.

If necessary, document commands such as:

```bash
flutterfire configure
```

and explain how to select the correct Firebase project for each environment.

The final implementation must make it obvious which Firebase project belongs to which flavor.

---

# 15. Important: PROD Firebase Is Not Connected Yet

At the moment, the PROD Firebase project is **not connected** to this Flutter project.

Therefore:

### Do now

Implement the complete flavor architecture:

```text
UAT
PROD
```

Configure UAT completely using the existing Firebase project.

Prepare the PROD structure so that the new Firebase project can be connected cleanly.

### Do not

Do NOT:

- use UAT credentials for PROD
- copy UAT `google-services.json` into PROD
- create fake PROD Firebase credentials
- invent a Firebase project ID
- replace the existing UAT Firebase configuration
- break the existing Firebase integration

If the actual PROD Firebase project configuration is not available, leave a clearly documented placeholder and explain exactly which files/configuration are required to complete the PROD connection.

---

# 16. Firebase Services Audit

Before finishing, scan the entire Flutter project and identify every Firebase integration currently used.

Check:

```text
Firebase Core
Firebase Auth
Firestore
Storage
Cloud Functions
Messaging / FCM
Remote Config
App Check
Crashlytics
Analytics
Dynamic Links / App Links if applicable
```

For every Firebase service, verify that it respects the selected UAT/PROD environment.

Do not assume that changing only `google-services.json` is sufficient.

---

# 17. Environment Safety

Add safeguards to prevent accidental production usage during development.

For example:

```text
UAT → clearly marked UAT
PROD → production
```

The application should make it obvious which environment is running.

Do not add unnecessary production restrictions that prevent legitimate production use.

---

# 18. Run Commands

After implementation, these commands should work:

### UAT

```bash
flutter clean
flutter pub get
flutter run --flavor uat -t lib/main_uat.dart
```

### PROD

```bash
flutter clean
flutter pub get
flutter run --flavor prod -t lib/main_prod.dart
```

Build UAT:

```bash
flutter build apk --flavor uat -t lib/main_uat.dart
```

Build PROD:

```bash
flutter build apk --flavor prod -t lib/main_prod.dart
```

Production release:

```bash
flutter build appbundle --release --flavor prod -t lib/main_prod.dart
```

Adjust commands if the final project structure uses a different entry-point strategy.

---

# 19. Validation / Testing

After implementation, verify both environments independently.

### UAT Test

Run:

```bash
flutter run --flavor uat -t lib/main_uat.dart
```

Verify:

- Firebase initializes successfully
- Firebase project ID is UAT
- Authentication uses UAT
- Firestore reads/writes UAT data
- Storage uses UAT
- Notifications use UAT configuration
- Other existing Firebase features continue working

### PROD Test

If PROD Firebase credentials are not yet available:

- Verify the PROD flavor builds successfully
- Verify PROD configuration is isolated
- Verify no UAT Firebase configuration is accidentally used
- Clearly document the remaining PROD Firebase setup

Once PROD Firebase credentials are available:

```bash
flutter run --flavor prod -t lib/main_prod.dart
```

Verify every Firebase service points to the PROD project.

---

# 20. Do Not Break Existing Functionality

This is an existing Flutter project.

Before modifying anything:

1. Analyze the complete project.
2. Identify the current Firebase setup.
3. Identify the current Android/iOS configuration.
4. Identify the current entry point.
5. Identify all Firebase services being used.
6. Identify the current package/bundle ID.
7. Identify the existing architecture.
8. Preserve all existing application functionality.

Do not rewrite unrelated code.

Do not upgrade Flutter, Dart, Kotlin, Gradle, or Firebase packages unless absolutely required.

Do not remove existing dependencies.

Do not change business logic.

Do not change UI unnecessarily.

Only make changes required for UAT/PROD environment support.

---

# 21. Final Deliverables

After completing the implementation, provide:

### A. Files created

List every new file.

Example:

```text
lib/main_uat.dart
lib/main_prod.dart
lib/config/environment.dart
lib/firebase/firebase_options_uat.dart
lib/firebase/firebase_options_prod.dart
android/app/src/uat/google-services.json
android/app/src/prod/google-services.json
...
```

### B. Files modified

List every existing file modified and explain why.

### C. UAT Firebase configuration

Clearly explain how the existing Firebase project is now configured as UAT.

### D. PROD Firebase configuration

Clearly explain whether PROD is:

```text
Connected
```

or:

```text
Prepared but waiting for PROD Firebase configuration
```

Do not claim PROD is connected if the actual Firebase project credentials were not provided.

### E. Commands

Provide exact commands for:

```text
Run UAT
Run PROD
Build UAT APK
Build PROD APK
Build UAT AAB
Build PROD AAB
```

### F. Firebase setup instructions

If PROD Firebase is still pending, provide the exact steps required to connect the new PROD Firebase project later.

---

# 22. Final Requirement

The final project must have a clean, production-ready environment architecture:

```text
                    Flutter Project
                          │
             ┌────────────┴────────────┐
             │                         │
          UAT Flavor              PROD Flavor
             │                         │
             ▼                         ▼
      Existing Firebase          New Firebase
          Project                   Project
             │                         │
             ▼                         ▼
        UAT Database             PROD Database
```

**Most important requirement:**

The existing Firebase connection is **UAT**.

The new PROD Firebase connection is **separate**.

The PROD Firebase project is currently **not connected**, so do not invent or reuse UAT credentials for PROD.

Implement the flavor architecture now and make the PROD connection easy to add later without changing the application/business logic.