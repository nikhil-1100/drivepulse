import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class EncryptionException implements Exception {
  const EncryptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Password-based file encryption that works entirely offline.
///
/// Container format (version 1):
///
/// ```
/// 0..3    magic  "DPV1"
/// 4..19   PBKDF2-HMAC-SHA256 salt (16 bytes)
/// 20..31  AES-GCM nonce / IV (12 bytes)
/// 32..n-17 ciphertext
/// n-16..n AES-GCM authentication tag (16 bytes)
/// ```
///
/// PBKDF2 runs 120 000 iterations. The password is never stored, so a lost
/// passphrase means unrecoverable data — the UI states this before encrypting.
class EncryptionService {
  EncryptionService({int iterations = 120000})
      : _pbkdf2 = Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: iterations,
          bits: 256,
        );

  final Pbkdf2 _pbkdf2;
  static const List<int> _magic = <int>[0x44, 0x50, 0x56, 0x31]; // DPV1
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const int _headerLength = 4 + _saltLength + _nonceLength;

  static final AesGcm _cipher = AesGcm.with256bits();

  bool isEncrypted(Uint8List bytes) {
    if (bytes.length < _headerLength + _macLength) return false;
    for (int i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  Future<Uint8List> encrypt(Uint8List plaintext, String password) async {
    if (password.length < 8) {
      throw const EncryptionException('Use a passphrase of at least 8 characters.');
    }
    final List<int> salt = _randomBytes(_saltLength);
    final SecretKey key = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final SecretBox box = await _cipher.encrypt(
      plaintext,
      secretKey: key,
      nonce: _randomBytes(_nonceLength),
    );

    final BytesBuilder builder = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(salt)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return builder.takeBytes();
  }

  Future<Uint8List> decrypt(Uint8List container, String password) async {
    if (!isEncrypted(container)) {
      throw const EncryptionException('This is not a DrivePulse encrypted file.');
    }
    final List<int> salt =
        container.sublist(4, 4 + _saltLength);
    final List<int> nonce = container.sublist(
      4 + _saltLength,
      _headerLength,
    );
    final List<int> cipherText = container.sublist(
      _headerLength,
      container.length - _macLength,
    );
    final List<int> mac = container.sublist(container.length - _macLength);

    final SecretKey key = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    try {
      final List<int> clear = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const EncryptionException(
        'Wrong passphrase, or the file has been modified.',
      );
    } on FormatException {
      throw const EncryptionException('The encrypted file is corrupt.');
    }
  }

  /// 64-character hex digest, used by the integrity check in History.
  Future<String> digest(Uint8List bytes) async {
    final Hash hash = await Sha256().hash(bytes);
    return hash.bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Encrypted filename: `report.pdf` → `report.pdf.dpv`.
  static String encryptedName(String name) => '$name.dpv';

  /// Strips the `.dpv` suffix, or returns null when the file is not one.
  static String? originalName(String name) {
    if (!name.toLowerCase().endsWith('.dpv')) return null;
    final String stripped = name.substring(0, name.length - 4);
    return stripped.isEmpty ? null : stripped;
  }

  static List<int> _randomBytes(int length) {
    final Random random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  String describe(Uint8List container) {
    if (!isEncrypted(container)) return 'Not encrypted';
    final int payload = container.length - _headerLength - _macLength;
    return 'AES-256-GCM • ${utf8.encode(payload.toString()).isNotEmpty ? payload : payload} bytes payload';
  }
}
