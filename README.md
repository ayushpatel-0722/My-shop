# My Shop (Bazaar)

A multi-tenant e-commerce marketplace built with Flutter and Firebase. Customers browse stores and order products, store admins manage their catalog and orders, and employees pick and pack orders. The UI supports English, Hindi, and Gujarati.

## Features

| Role | Capabilities |
| --- | --- |
| **Customer** | Browse stores, categories and products, search, cart and wishlist with variant snapshots, checkout with saved addresses, vouchers and delivery charges, order tracking with ETA, reviews, notifications, QR scan and deep links |
| **Admin** | Dashboard, products (variants and structured content), categories (drag ordering), vouchers, delivery charges by pincode, banners, recommendations, reviews, employees and admins, QR codes, Excel/PDF reports |
| **Employee** | Order queue and packing screen |

Other features:

- Company onboarding creates a store and its first admin through a Cloud Function.
- A mock mode runs the whole app with in-memory data, with no backend.
- Force-update gate driven by Firebase Remote Config.
- Push notifications (FCM), App Check, and secure session cache.

## Tech stack

- **Flutter** 3.44+ / Dart ^3.12
- **State:** `flutter_bloc` (cubits). **Routing:** `go_router`
- **Backend:** Firebase Auth, Firestore, Realtime Database, Cloud Functions, Messaging, Remote Config, App Check, Storage
- **i18n:** ARB files + `flutter gen-l10n`

## Project structure

```
lib/
├── main.dart            # Firebase init, DI wiring, app bootstrap
├── main_uat.dart        # UAT flavor entry point (main_prod.dart for PROD)
├── app/                 # App widget, router, theme, l10n (en/hi/gu)
├── core/
│   ├── config/          # AppConfig (flags, min version)
│   ├── domain/          # Pure business logic (pricing, vouchers, order status, ...)
│   ├── models/          # Data models
│   ├── repositories/    # AppRepository interface
│   ├── database/        # FirebaseAppRepository + MockAppRepository
│   ├── services/        # Auth session, notifications, deep links, reports, ...
│   ├── utils/           # Formatters, responsive helpers, route logger
│   └── widgets/         # Shared UI components
└── features/            # One folder per feature: account, admin, auth, checkout,
                         # employee, marketplace, product, reviews, ...
functions/               # Firebase Cloud Functions (Node)
platform_setup/          # Deep-link / manifest reference files
test/                    # Domain, model, repository and widget tests
```

Screens talk only to the `AppRepository` interface (`repo` from `service_locator.dart`). `ServiceLocator.init` picks the Firebase or mock implementation at startup.

## Getting started

### Prerequisites

- Flutter SDK 3.44+ ([install](https://docs.flutter.dev/get-started/install))
- Node.js 18+ and the [Firebase CLI](https://firebase.google.com/docs/cli) (only for backend work)
- `make` (preinstalled on macOS and Linux)

### Install and run

```bash
make setup      # flutter pub get + functions npm install
make run-mock   # run with in-memory data, no Firebase required
make run        # run against Firebase
make run-uat    # UAT flavor (lib/main_uat.dart)
make run-prod   # PROD flavor (lib/main_prod.dart)
make run DEVICE=chrome   # pick a device
```

Run `make help` to list every command.

### Connect your own Firebase project

The repo ships with a sample Firebase config. To use your own:

1. Install the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli): `dart pub global activate flutterfire_cli`
2. Run `flutterfire configure`. This regenerates `lib/firebase_options.dart` and the platform config files.
3. Deploy the backend: `make rules-deploy` and `make functions-deploy`.
4. Optional: for App Check on debug builds, set the debug tokens in [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart). On web, App Check is skipped because it needs reCAPTCHA.

If Firebase fails to initialize, the app falls back to mock mode automatically.

## Common commands

| Command | Description |
| --- | --- |
| `make run` / `run-uat` / `run-prod` | Run the app (default / UAT flavor / PROD flavor) |
| `make run-mock` / `make web` | Run with mock data / in Chrome on :8080 |
| `make format` / `make format-check` | Format Dart code / verify formatting |
| `make analyze` | Static analysis |
| `make test` / `make coverage` | Run tests / with coverage |
| `make check` | Format check, analyze and test (run before pushing) |
| `make l10n` | Regenerate localizations after editing `.arb` files |
| `make build-apk` / `build-appbundle` / `build-web` | Release builds |
| `make functions-deploy` / `rules-deploy` | Deploy Cloud Functions / security rules |

## Localization

Strings live in `lib/app/l10n/app_en.arb` (template), `app_hi.arb` and `app_gu.arb`. Add a key to all three, then run `make l10n`. Use it as `AppLocalizations.of(context).yourKey`.

## Testing

Tests cover domain logic (`test/domain`), models, the mock repositories, and widget tests for the main screens. Shared setup is in `test/helpers/test_harness.dart`.

```bash
make test
flutter test test/domain          # one folder
flutter test test/features/cart_screen_test.dart
```

## Deep links

Universal and app links are configured through the files in [`platform_setup/`](platform_setup/): `apple-app-site-association`, `assetlinks.json`, and the Android manifest and iOS Info.plist reference snippets. Route builders are in `AppRoutes` ([`app_router.dart`](lib/app/routes/app_router.dart)).

## Security notes

**Company (shop) password.** It is stored as a salted PBKDF2-SHA256 hash
(`lib/core/services/company_password.dart`). Passwords saved as plain text
before this existed still work and are upgraded to a hash automatically the
next time that shop's admin signs in.

What is **not** solved yet, and needs a deployment with Firebase credentials:

- Shop documents are publicly readable (`firestore.rules`), so the *hash* is
  public too, and the password is still checked inside the app. To close this
  properly:
  1. Add a Cloud Function (for example `verifyCompanyPassword`) that checks the
     password on the server and returns only pass/fail.
  2. Move the hash out of the public `companies/{id}` document into a
     server-only location, and deny client reads of it in `firestore.rules`.
  3. Switch the two login checks (`admin_login_screen.dart` step 1 and
     `FirebaseAppRepository.adminLogin`) to call the function.
  4. Deploy: `make functions-deploy` and `make rules-deploy`.
- Do the deployment steps together; switching the app before the function is
  live would stop every admin from logging in.

## Contributing

1. Create a branch from `main`.
2. Keep business logic in `core/domain` so it can be unit tested without Flutter.
3. Run `make check` before opening a PR.
