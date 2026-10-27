import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/services/company_password.dart';

void main() {
  group('hash', () {
    test('matches the RFC 7914 PBKDF2-HMAC-SHA256 test vector', () {
      // P="passwd", S="salt", c=1, dkLen=64 (first 32 bytes checked here
      // through a 32-byte derivation): known value from RFC 7914 §11.
      final stored = CompanyPassword.hash(
        'passwd',
        salt: utf8.encode('salt'),
        iterations: 1,
      );
      final derived = base64.decode(stored.split('\$')[3]);
      final hex = derived
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(
        hex,
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc',
      );
    });

    test('is salted: the same password hashes differently each time', () {
      final a = CompanyPassword.hash('Secret@1');
      final b = CompanyPassword.hash('Secret@1');
      expect(a, isNot(b));
      expect(CompanyPassword.isHashed(a), isTrue);
    });

    test('never contains the password', () {
      expect(CompanyPassword.hash('Secret@1'), isNot(contains('Secret@1')));
    });
  });

  group('verify', () {
    test('accepts the right password and rejects others', () {
      final stored = CompanyPassword.hash('Secret@1');
      expect(CompanyPassword.verify('Secret@1', stored), isTrue);
      expect(CompanyPassword.verify('secret@1', stored), isFalse);
      expect(CompanyPassword.verify('Secret@2', stored), isFalse);
      expect(CompanyPassword.verify('', stored), isFalse);
    });

    test('ignores surrounding spaces like the login form does', () {
      final stored = CompanyPassword.hash('  Secret@1 ');
      expect(CompanyPassword.verify('Secret@1', stored), isTrue);
      expect(CompanyPassword.verify(' Secret@1  ', stored), isTrue);
    });

    test('still accepts a legacy plain-text password', () {
      expect(CompanyPassword.verify('green@123', 'green@123'), isTrue);
      expect(CompanyPassword.verify('green@124', 'green@123'), isFalse);
    });

    test('an empty stored value never matches, even an empty entry', () {
      expect(CompanyPassword.verify('', ''), isFalse);
      expect(CompanyPassword.verify('anything', '   '), isFalse);
    });

    test('malformed or tampered hashes do not match (and do not throw)', () {
      final stored = CompanyPassword.hash('Secret@1');
      final parts = stored.split('\$');
      final badSalt = [parts[0], parts[1], '%%%', parts[3]].join('\$');
      final badIter = [parts[0], 'x', parts[2], parts[3]].join('\$');
      final zeroIter = [parts[0], '0', parts[2], parts[3]].join('\$');
      final truncated = '${parts[0]}\$${parts[1]}\$${parts[2]}';
      for (final bad in [badSalt, badIter, zeroIter, truncated]) {
        expect(CompanyPassword.verify('Secret@1', bad), isFalse, reason: bad);
      }
      // Changing a character of the hash breaks it.
      final last = stored[stored.length - 3];
      final flipped =
          '${stored.substring(0, stored.length - 3)}${last == 'A' ? 'B' : 'A'}'
          '${stored.substring(stored.length - 2)}';
      expect(CompanyPassword.verify('Secret@1', flipped), isFalse);
    });

    test('a hash is not accepted as if it were the password', () {
      final stored = CompanyPassword.hash('Secret@1');
      expect(CompanyPassword.verify(stored, stored), isFalse);
    });
  });

  group('needsUpgrade', () {
    test('only non-empty legacy plain text needs upgrading', () {
      expect(CompanyPassword.needsUpgrade('green@123'), isTrue);
      expect(CompanyPassword.needsUpgrade(CompanyPassword.hash('x')), isFalse);
      expect(CompanyPassword.needsUpgrade(''), isFalse);
      expect(CompanyPassword.needsUpgrade('  '), isFalse);
    });
  });
}
