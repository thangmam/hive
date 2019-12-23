import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/crypto_helper.dart';

class FrameHelper {
  int framesFromBytes(Uint8List bytes, Keystore keystore, TypeRegistry registry,
      CryptoHelper crypto) {
    final reader = BinaryReaderImpl(bytes, registry);

    while (reader.availableBytes != 0) {
      final frameOffset = reader.usedBytes;

      final frame = reader.readFrame(
        crypto: crypto,
        lazy: false,
        frameOffset: frameOffset,
      );
      if (frame == null) return frameOffset;

      keystore.insert(frame, notify: false);
    }

    return -1;
  }
}
