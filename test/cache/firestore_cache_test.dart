import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/cache/cache_consent.dart';
import 'package:myshop/core/cache/cache_policy.dart';
import 'package:myshop/core/cache/firestore_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('settings', () {
    test('Android / iOS: persistent and bounded, no consent needed', () {
      for (final c in CacheConsent.values) {
        final s = FirestoreCache.settingsFor(isWeb: false, consent: c);
        expect(s.persistenceEnabled, isTrue);
        expect(s.cacheSizeBytes, CachePolicy.standard.firestoreCacheBytes);
      }
    });

    test('web allowed: persistent (IndexedDB) and bounded', () {
      final s = FirestoreCache.settingsFor(
        isWeb: true,
        consent: CacheConsent.allowed,
      );
      expect(s.persistenceEnabled, isTrue);
      expect(s.cacheSizeBytes, CachePolicy.standard.firestoreCacheBytes);
      expect(s.webPersistentTabManager, isNotNull);
    });

    test('web declined or undecided: nothing is kept on disk', () {
      for (final c in [CacheConsent.declined, CacheConsent.undecided]) {
        final s = FirestoreCache.settingsFor(isWeb: true, consent: c);
        expect(s.persistenceEnabled, isFalse);
        expect(s.webPersistentTabManager, isNull);
      }
    });

    test(
      'the size limit follows the policy and is within Firestore\'s range',
      () {
        const p = CachePolicy(firestoreCacheBytes: 10 * 1024 * 1024);
        expect(
          FirestoreCache.settingsFor(
            isWeb: false,
            consent: CacheConsent.allowed,
            policy: p,
          ).cacheSizeBytes,
          10 * 1024 * 1024,
        );
        final std = CachePolicy.standard.firestoreCacheBytes;
        expect(std, inInclusiveRange(1048576, 104857600));
      },
    );
  });

  group('clearing on account change', () {
    test('marked, then reported as pending', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await FirestoreCache.isClearPending(), isFalse);
      await FirestoreCache.markForClearing();
      expect(await FirestoreCache.isClearPending(), isTrue);
    });
  });

  group('policy', () {
    test('defaults are bounded and shorter for fast-changing data', () {
      const p = CachePolicy.standard;
      expect(p.imageCacheBytes, lessThanOrEqualTo(100 * 1024 * 1024));
      expect(p.imageMaxFileBytes, lessThan(p.imageCacheBytes));
      expect(
        p.maxAgeFor(DataClass.volatile),
        lessThan(p.maxAgeFor(DataClass.catalog)),
      );
      expect(
        p.maxAgeFor(DataClass.catalog),
        lessThan(p.maxAgeFor(DataClass.reference)),
      );
      expect(
        p.keepAliveFor(DataClass.volatile),
        lessThan(p.keepAliveFor(DataClass.reference)),
      );
    });
  });
}
