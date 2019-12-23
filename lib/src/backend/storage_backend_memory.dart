import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/backend/storage_backend.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/binary/frame_helper.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/crypto_helper.dart';
import 'package:meta/meta.dart';

class StorageBackendMemory extends StorageBackend {
  final CryptoHelper crypto;

  final FrameHelper frameHelper;

  Uint8List _bytes;

  StorageBackendMemory(this._bytes, this.crypto) : frameHelper = FrameHelper();

  @override
  String get path => null;

  @override
  bool supportsCompaction = false;

  @override
  Future<void> initialize(TypeRegistry registry, Keystore keystore,
      {@required bool lazy}) {
    final recoveryOffset =
        frameHelper.framesFromBytes(_bytes, keystore, registry, crypto);

    if (recoveryOffset != -1) {
      throw HiveError('Wrong checksum in bytes. Box may be corrupted.');
    }

    _bytes = null;

    return Future.value();
  }

  @override
  Future<dynamic> readValue(Frame frame) {
    throw UnsupportedError('This operation is unsupported for memory boxes.');
  }

  @override
  Future<void> writeFrames(List<Frame> frames) => Future.value();

  @override
  Future<List<Frame>> compact(Iterable<Frame> frames) {
    throw UnsupportedError('This operation is unsupported for memory boxes.');
  }

  @override
  Future<void> clear() => Future.value();

  @override
  Future<void> close() => Future.value();

  @override
  Future<void> deleteFromDisk() {
    throw UnsupportedError('This operation is unsupported for memory boxes.');
  }
}
