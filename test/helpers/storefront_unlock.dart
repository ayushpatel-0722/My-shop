import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/database/mock_app_repository.dart';
import 'package:myshop/core/services/company_password.dart';

/// A throwaway password for tests; the real one is a salted hash in Firebase.
const testStorefrontPassword = 'test-only-secret';

/// Makes the mock "Firebase" hold a password for the storefront lock.
void configureStorefrontLock(MockAppRepository repo) {
  repo.storefrontLockHashValue = CompanyPassword.hash(
    testStorefrontPassword,
    iterations: 1000,
  );
}

/// Opens a locked storefront section through its unlock dialog.
Future<void> unlockStorefront(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('storefront-lock-button')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('storefront-password-field')),
    testStorefrontPassword,
  );
  await tester.tap(find.byKey(const Key('storefront-unlock-submit')));
  await tester.pumpAndSettle();
}
