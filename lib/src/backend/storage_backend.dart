import 'package:hive/hive.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/crypto_helper.dart';
import 'package:meta/meta.dart';

export 'package:hive/src/backend/stub/backend_manager.dart'
    if (dart.library.io) 'package:hive/src/backend/vm/backend_manager.dart'
    if (dart.library.html) 'package:hive/src/backend/js/backend_manager.dart';

abstract class StorageBackend {
  String get path;

  bool get supportsCompaction;

  Future<void> initialize(TypeRegistry registry, Keystore keystore,
      {@required bool lazy});

  Future<dynamic> readValue(Frame frame);

  Future<void> writeFrames(List<Frame> frames);

  Future<void> compact(Iterable<Frame> frames);

  Future<void> clear();

  Future<void> close();

  Future<void> deleteFromDisk();
}

abstract class BackendManagerInterface {
  Future<StorageBackend> open(String name, String path, CryptoHelper crypto,
      {@required bool crashRecovery});

  Future<void> deleteBox(String name, String path);
}
