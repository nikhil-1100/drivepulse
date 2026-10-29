import 'dart:typed_data';

import 'package:drivepulse/data/services/encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Low iteration count keeps the test fast; production uses 120,000.
  final EncryptionService service = EncryptionService(iterations: 1000);

  test('round-trips a payload', () async {
    final Uint8List plain = Uint8List.fromList(
      List<int>.generate(4096, (int i) => i % 256),
    );
    final Uint8List sealed = await service.encrypt(plain, 'correct horse battery');
    expect(service.isEncrypted(sealed), isTrue);
    expect(sealed.length, greaterThan(plain.length));

    final Uint8List restored =
        await service.decrypt(sealed, 'correct horse battery');
    expect(restored, equals(plain));
  });

  test('rejects a wrong passphrase', () async {
    final Uint8List sealed =
        await service.encrypt(Uint8List.fromList(<int>[1, 2, 3, 4]), 'passphrase-1');
    expect(
      () => service.decrypt(sealed, 'passphrase-2'),
      throwsA(isA<EncryptionException>()),
    );
  });

  test('detects tampering', () async {
    final Uint8List sealed =
        await service.encrypt(Uint8List.fromList(<int>[9, 8, 7, 6]), 'passphrase-1');
    sealed[sealed.length - 20] ^= 0xFF;
    expect(
      () => service.decrypt(sealed, 'passphrase-1'),
      throwsA(isA<EncryptionException>()),
    );
  });

  test('rejects plain files and short passphrases', () async {
    expect(service.isEncrypted(Uint8List.fromList(<int>[1, 2, 3])), isFalse);
    expect(
      () => service.encrypt(Uint8List.fromList(<int>[1]), 'short'),
      throwsA(isA<EncryptionException>()),
    );
    expect(
      () => service.decrypt(Uint8List.fromList(List<int>.filled(64, 0)), 'whatever'),
      throwsA(isA<EncryptionException>()),
    );
  });

  test('container naming helpers', () {
    expect(EncryptionService.encryptedName('report.pdf'), 'report.pdf.dpv');
    expect(EncryptionService.originalName('report.pdf.dpv'), 'report.pdf');
    expect(EncryptionService.originalName('report.pdf'), isNull);
  });
}
