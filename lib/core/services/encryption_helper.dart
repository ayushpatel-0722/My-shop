import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Provides authenticated symmetric encryption and decryption for local storage
/// using HMAC-SHA256 in Counter (CTR) stream mode with tamper verification.
///
/// Features:
/// - Cryptographically secure 16-byte random IV for every encryption call.
/// - HMAC-SHA256 keystream generation with big-endian block indexing.
/// - Authenticated ciphertext integrity MAC to detect tampering.
/// - Pure Dart implementation — 100% cross-platform (Web, Android, iOS, Desktop).
class EncryptionHelper {
  EncryptionHelper._();

  // App-specific salt key for deriving session vault encryption keys.
  static const String _masterKeySeed =
      'Bazaar_Secure_Vault_Key_v1_8f9c2d1e0a4b7c6d5e8f';

  static final List<int> _encKey = Hmac(
    sha256,
    utf8.encode('enc_key_salt'),
  ).convert(utf8.encode(_masterKeySeed)).bytes;

  static final List<int> _macKey = Hmac(
    sha256,
    utf8.encode('mac_key_salt'),
  ).convert(utf8.encode(_masterKeySeed)).bytes;

  static const String _prefix = 'ENC:';

  /// Encrypts [plainText] into a tamper-resistant Base64 string prefixed with 'ENC:'.
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';

    final plainBytes = utf8.encode(plainText);

    // 1. Generate random 16-byte IV
    final rng = Random.secure();
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = rng.nextInt(256);
    }

    // 2. Generate keystream using HMAC-SHA256 CTR mode
    final cipherBytes = Uint8List(plainBytes.length);
    final blockCount = (plainBytes.length + 31) ~/ 32;

    for (var block = 0; block < blockCount; block++) {
      final counterBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, block, Endian.big);

      final streamInput = Uint8List(iv.length + counterBytes.length)
        ..setRange(0, iv.length, iv)
        ..setRange(iv.length, iv.length + counterBytes.length, counterBytes);

      final keyBlock = Hmac(sha256, _encKey).convert(streamInput).bytes;

      final start = block * 32;
      final end = min(start + 32, plainBytes.length);
      for (var j = start; j < end; j++) {
        cipherBytes[j] = plainBytes[j] ^ keyBlock[j - start];
      }
    }

    // 3. Compute HMAC tag over IV + ciphertext for integrity verification
    final macInput = Uint8List(iv.length + cipherBytes.length)
      ..setRange(0, iv.length, iv)
      ..setRange(iv.length, iv.length + cipherBytes.length, cipherBytes);

    final mac = Hmac(sha256, _macKey).convert(macInput).bytes;

    // 4. Serialize to JSON container
    final container = {
      'v': 1,
      'iv': base64Encode(iv),
      'ct': base64Encode(cipherBytes),
      'mac': base64Encode(mac),
    };

    return '$_prefix${base64Encode(utf8.encode(jsonEncode(container)))}';
  }

  /// Decrypts [cipherText]. If [cipherText] is legacy unencrypted JSON, returns it directly.
  static String decrypt(String cipherText) {
    if (cipherText.isEmpty) return '';

    // Graceful backward compatibility with unencrypted legacy cache
    if (!cipherText.startsWith(_prefix)) {
      return cipherText;
    }

    try {
      final raw = cipherText.substring(_prefix.length);
      final decodedJson = utf8.decode(base64Decode(raw));
      final map = jsonDecode(decodedJson) as Map<String, dynamic>;

      final iv = base64Decode(map['iv'] as String);
      final cipherBytes = base64Decode(map['ct'] as String);
      final expectedMac = base64Decode(map['mac'] as String);

      // Verify MAC integrity
      final macInput = Uint8List(iv.length + cipherBytes.length)
        ..setRange(0, iv.length, iv)
        ..setRange(iv.length, iv.length + cipherBytes.length, cipherBytes);

      final actualMac = Hmac(sha256, _macKey).convert(macInput).bytes;

      if (!_constantTimeEquals(expectedMac, actualMac)) {
        return ''; // Tampered or corrupted data
      }

      // Decrypt using HMAC-SHA256 CTR mode
      final plainBytes = Uint8List(cipherBytes.length);
      final blockCount = (cipherBytes.length + 31) ~/ 32;

      for (var block = 0; block < blockCount; block++) {
        final counterBytes = Uint8List(4)
          ..buffer.asByteData().setUint32(0, block, Endian.big);

        final streamInput = Uint8List(iv.length + counterBytes.length)
          ..setRange(0, iv.length, iv)
          ..setRange(iv.length, iv.length + counterBytes.length, counterBytes);

        final keyBlock = Hmac(sha256, _encKey).convert(streamInput).bytes;

        final start = block * 32;
        final end = min(start + 32, cipherBytes.length);
        for (var j = start; j < end; j++) {
          plainBytes[j] = cipherBytes[j] ^ keyBlock[j - start];
        }
      }

      return utf8.decode(plainBytes);
    } catch (_) {
      return '';
    }
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

