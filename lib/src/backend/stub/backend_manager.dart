import 'package:hive/src/backend/storage_backend.dart';
import 'package:hive/src/crypto_helper.dart';
import 'package:meta/meta.dart';

class BackendManager implements BackendManagerInterface {
  @override
  Future<StorageBackend> open(String name, String path, CryptoHelper crypto,
      {@required bool crashRecovery}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBox(String name, String path) {
    throw UnimplementedError();
  }
}
