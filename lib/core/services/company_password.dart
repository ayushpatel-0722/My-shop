import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Storage and checking of a shop's "company password".
///
/// New passwords are stored as `pbkdf2-sha256$<iterations>$<salt>$<hash>`
/// (salted PBKDF2-HMAC-SHA256) instead of plain text. Passwords saved before
/// this existed are still accepted and are upgraded to a hash the next time
/// the shop's admin signs in (see [needsUpgrade]).
///
/// NOTE: the shop record is still readable by anyone, so the hash is too. This
/// makes the stored value far harder to abuse than plain text, but the real fix
/// is to check the password on a server and stop exposing it; see
/// "Security notes" in the README.
class CompanyPassword {
  CompanyPassword._();

  static const _scheme = 'pbkdf2-sha256';
  static const _defaultIterations = 10000;
  static const _saltBytes = 16;
  static const _hashBytes = 32;

  /// True when [stored] is in the hashed format.
  static bool isHashed(String stored) => stored.startsWith('$_scheme\$');

  /// True when [stored] is a legacy plain-text value that should be re-saved
  /// as a hash after a successful check.
  static bool needsUpgrade(String stored) =>
      stored.trim().isNotEmpty && !isHashed(stored);

  /// Hashes [password] with a fresh random salt (or the given [salt], for
  /// tests).
  static String hash(
    String password, {
    List<int>? salt,
    int iterations = _defaultIterations,
  }) {
    final s =
        salt ??
        (() {
          final rng = Random.secure();
          return List<int>.generate(_saltBytes, (_) => rng.nextInt(256));
        })();
    final derived = _pbkdf2(utf8.encode(password.trim()), s, iterations);
    return '$_scheme\$$iterations\$${base64.encode(s)}\$${base64.encode(derived)}';
  }

  /// Whether [entered] matches [stored], which may be hashed or legacy plain
  /// text. An empty stored value never matches.
  static bool verify(String entered, String stored) {
    final storedTrimmed = stored.trim();
    if (storedTrimmed.isEmpty) return false;
    if (!isHashed(storedTrimmed)) {
      return _constantTimeEquals(
        utf8.encode(entered.trim()),
        utf8.encode(storedTrimmed),
      );
    }
    final parts = storedTrimmed.split('\$');
    if (parts.length != 4) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    try {
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      final actual = _pbkdf2(
        utf8.encode(entered.trim()),
        salt,
        iterations,
        length: expected.length,
      );
      return _constantTimeEquals(actual, expected);
    } on FormatException {
      return false;
    }
  }

  // PBKDF2-HMAC-SHA256 (RFC 8018), pure Dart so it works on every platform.
  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations, {
    int length = _hashBytes,
  }) {
    final hmac = Hmac(sha256, password);
    final blocks = (length / 32).ceil();
    final out = BytesBuilder();
    for (var block = 1; block <= blocks; block++) {
      final index = ByteData(4)..setUint32(0, block);
      var u = hmac.convert([...salt, ...index.buffer.asUint8List()]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final n = min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
