import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Thin synchronous AES-256-GCM cipher used for end-to-end encryption of
/// all WebSocket payloads.
///
/// Wire format (encrypted message):
///   `e:<base64url(12-byte-nonce || ciphertext || 16-byte-mac)>`
///
/// If no cipher is configured, messages are sent as plain JSON (existing
/// behaviour).  The prefix `e:` distinguishes encrypted frames from plain JSON
/// so old/unencrypted clients can be detected.
///
/// Usage:
///   final cipher = CollaborationCipher.fromHex(hexKey);
///   final wire   = cipher.encryptWire(syncMsg.encode());
///   final json   = cipher.decryptWire(rawFrame);   // null on failure
class CollaborationCipher {
  CollaborationCipher._(this._keyData);

  final SecretKeyData _keyData;

  static final _algo = DartAesGcm.with256bits();
  static final _rng = Random.secure();

  // ── Factory ────────────────────────────────────────────────────────────────

  factory CollaborationCipher.fromBytes(List<int> bytes) {
    assert(bytes.length == 32, 'AES-256 key must be 32 bytes');
    return CollaborationCipher._(SecretKeyData(bytes));
  }

  factory CollaborationCipher.fromHex(String hex) {
    if (hex.length != 64) {
      throw ArgumentError('AES-256 key hex must be 64 chars (32 bytes)');
    }
    final bytes = List<int>.generate(
      32,
      (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
    );
    return CollaborationCipher.fromBytes(bytes);
  }

  // ── Encrypt ────────────────────────────────────────────────────────────────

  /// Encrypts [plainJson] and returns an `e:<base64>` wire string.
  String encryptWire(String plainJson) {
    final nonce = List<int>.generate(12, (_) => _rng.nextInt(256));
    final box = _algo.encryptSync(
      utf8.encode(plainJson),
      secretKeyData: _keyData,
      nonce: nonce,
    );
    // Concatenate nonce || ciphertext || mac
    final combined = <int>[
      ...box.nonce,       // 12 bytes
      ...box.cipherText,  // variable
      ...box.mac.bytes,   // 16 bytes
    ];
    return 'e:${base64Url.encode(combined)}';
  }

  // ── Decrypt ────────────────────────────────────────────────────────────────

  /// Decrypts an `e:<base64>` wire string back to plain JSON.
  /// Returns `null` if the frame is not an encrypted frame, or if
  /// decryption fails (wrong key / tampered data).
  String? decryptWire(String raw) {
    if (!raw.startsWith('e:')) return null;
    try {
      final bytes = base64Url.decode(raw.substring(2));
      if (bytes.length < 28) return null; // 12 nonce + 16 mac minimum
      final nonce = bytes.sublist(0, 12);
      final mac = Mac(bytes.sublist(bytes.length - 16));
      final cipherText = bytes.sublist(12, bytes.length - 16);
      final box = SecretBox(cipherText, nonce: nonce, mac: mac);
      final plain = _algo.decryptSync(box, secretKeyData: _keyData);
      return utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns a cryptographically secure random 32-byte key as a hex string.
  static String generateKeyHex() {
    final bytes = List<int>.generate(32, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Formats a hex key as 8 groups of 4 chars, easier to read/type.
  static String formatKeyForDisplay(String hex) {
    final groups = <String>[];
    for (int i = 0; i < 64; i += 8) {
      groups.add(hex.substring(i, i + 8));
    }
    return groups.join('-');
  }

  /// Removes dashes/spaces from a user-typed key and validates length.
  static String? normaliseKey(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-]'), '').toLowerCase();
    if (cleaned.length != 64) return null;
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(cleaned)) return null;
    return cleaned;
  }
}
