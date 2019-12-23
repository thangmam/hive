import 'dart:math';
import 'dart:typed_data';

import 'package:hive/src/util/crc32.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';

class CryptoHelper {
  final Uint8List keyBytes;
  final int keyCrc;
  final BlockCipher cipher;
  final SecureRandom random;

  CryptoHelper(this.keyBytes)
      : keyCrc = Crc32.compute(Digest('SHA-256').process(keyBytes)),
        cipher = PaddedBlockCipher('AES/CBC/PKCS7'),
        random = createSecureRandom();

  CryptoHelper.debug(this.keyBytes, this.random)
      : keyCrc = Crc32.compute(Digest('SHA-256').process(keyBytes)),
        cipher = PaddedBlockCipher('AES/CBC/PKCS7');

  static SecureRandom createSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seed = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      seed[i] = random.nextInt(255);
    }
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  Uint8List encrypt(Uint8List bytes) {
    final iv = random.nextBytes(16);
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(keyBytes), iv),
      null,
    );

    cipher.reset();
    cipher.init(true, params);

    final encrypted = cipher.process(bytes);
    final result = Uint8List(iv.length + encrypted.length);
    result.setAll(0, iv);
    result.setAll(iv.length, encrypted);
    return result;
  }

  Uint8List decrypt(Uint8List bytes) {
    final iv = Uint8List.view(bytes.buffer, bytes.offsetInBytes, 16);
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(keyBytes), iv),
      null,
    );

    cipher.reset();
    cipher.init(false, params);

    final encryptedBytes = Uint8List.view(
      bytes.buffer,
      bytes.offsetInBytes + 16,
      bytes.length - 16,
    );
    return cipher.process(encryptedBytes);
  }
}
