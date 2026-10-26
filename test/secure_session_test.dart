import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/app_user.dart';
import 'package:myshop/core/services/auth_session.dart';
import 'package:myshop/core/services/encryption_helper.dart';
import 'package:myshop/core/services/secure_session_cache.dart';
import 'package:myshop/core/services/service_locator.dart';
import 'package:myshop/features/auth/auth_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ServiceLocator.instance.init(firebaseReady: false);
    AuthSession.set(null, restoring: false);
  });

  group('EncryptionHelper Tests', () {
    test('encrypts plaintext into an ENC: prefixed ciphertext', () {
      const plain = '{"id":"admin_123","role":"admin","companyId":"comp_abc"}';
      final cipher = EncryptionHelper.encrypt(plain);

      expect(cipher.startsWith('ENC:'), isTrue);
      expect(cipher, isNot(equals(plain)));
      expect(cipher.contains('admin_123'), isFalse);
    });

    test('decrypts encrypted string back to identical plaintext', () {
      const plain = '{"id":"admin_456","name":"Rajesh Patel","role":"admin"}';
      final cipher = EncryptionHelper.encrypt(plain);
      final decrypted = EncryptionHelper.decrypt(cipher);

      expect(decrypted, equals(plain));
    });

    test('supports UTF-8 international characters (Hindi & Gujarati)', () {
      const plain = '{"name":"રાજેશ પટેલ","desc":"ऑर्गेनिक सब्जियां"}';
      final cipher = EncryptionHelper.encrypt(plain);
      final decrypted = EncryptionHelper.decrypt(cipher);

      expect(decrypted, equals(plain));
    });

    test('rejects tampered ciphertext gracefully', () {
      const plain = 'sensitive admin session token';
      final cipher = EncryptionHelper.encrypt(plain);

      // Tamper with one character in the payload
      final tampered = '${cipher.substring(0, cipher.length - 6)}AAAA==';
      final result = EncryptionHelper.decrypt(tampered);

      expect(result, isEmpty);
    });

    test('passes legacy unencrypted string through unchanged', () {
      const legacy = '{"id":"legacy_user"}';
      expect(EncryptionHelper.decrypt(legacy), equals(legacy));
    });
  });

  group('SecureSessionCache & Encrypted Storage Tests', () {
    test('persists AppUser encrypted and restores correctly', () async {
      const user = AppUser(
        id: 'adm_007',
        name: 'Super Admin',
        companyId: 'company_77',
        companyName: 'Green Organics',
        email: 'admin@green.in',
        role: 'admin',
      );

      await SecureSessionCache.instance.save(user);

      // Verify that data in SharedPreferences is NOT stored in plain text
      final prefs = await SharedPreferences.getInstance();
      final storedRaw = prefs.getString('cached_app_user_v2');

      expect(storedRaw, isNotNull);
      expect(storedRaw!.startsWith('ENC:'), isTrue);
      expect(storedRaw.contains('admin@green.in'), isFalse);
      expect(storedRaw.contains('Super Admin'), isFalse);

      // Verify restore decrypts correctly
      final restored = await SecureSessionCache.instance.restore();
      expect(restored, isNotNull);
      expect(restored!.id, equals('adm_007'));
      expect(restored.name, equals('Super Admin'));
      expect(restored.companyId, equals('company_77'));
      expect(restored.companyName, equals('Green Organics'));
      expect(restored.role, equals('admin'));
      expect(restored.isAdmin, isTrue);
    });

    test('clear() wipes all encrypted local session data', () async {
      const user = AppUser(
        id: 'emp_01',
        name: 'John Doe',
        companyId: 'company_77',
        role: 'employee',
      );

      await SecureSessionCache.instance.save(user);
      expect(await SecureSessionCache.instance.restore(), isNotNull);

      await SecureSessionCache.instance.clear();

      final restoredAfterClear = await SecureSessionCache.instance.restore();
      expect(restoredAfterClear, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_app_user_v2'), isNull);
    });
  });

  group('AuthCubit Session Restoration Tests', () {
    test(
      'restores admin session from encrypted cache on startup without blank screen',
      () async {
        const adminUser = AppUser(
          id: 'admin_test_id',
          name: 'Ayush Admin',
          companyId: 'comp_test',
          companyName: 'Bazaar Mart',
          email: 'admin@bazaar.in',
          role: 'admin',
        );

        // Pre-seed the encrypted cache as if admin was logged in before reload
        await SecureSessionCache.instance.save(adminUser);

        // Create new AuthCubit (simulating app reload/restart)
        final cubit = AuthCubit();

        // Wait for async _restoreSession to complete
        await Future.delayed(const Duration(milliseconds: 100));

        expect(cubit.state.status, equals(AuthStatus.authenticated));
        expect(cubit.state.user?.id, equals('admin_test_id'));
        expect(cubit.state.user?.isAdmin, isTrue);
        expect(AuthSession.isAdmin, isTrue);
        expect(AuthSession.isRestoring, isFalse);
        expect(AuthSession.currentUser?.companyName, equals('Bazaar Mart'));

        await cubit.close();
      },
    );

    test('signOut clears both AuthSession and encrypted cache', () async {
      const user = AppUser(id: 'usr_1', name: 'Shopper', role: 'user');

      await SecureSessionCache.instance.save(user);
      AuthSession.set(user, restoring: false);

      final cubit = AuthCubit();
      await Future.delayed(const Duration(milliseconds: 50));

      await cubit.signOut();

      expect(cubit.state.status, equals(AuthStatus.unauthenticated));
      expect(cubit.state.user, isNull);
      expect(AuthSession.currentUser, isNull);
      expect(AuthSession.isAdmin, isFalse);

      final cached = await SecureSessionCache.instance.restore();
      expect(cached, isNull);

      await cubit.close();
    });
  });
}
