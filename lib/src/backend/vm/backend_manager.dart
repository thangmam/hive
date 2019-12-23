import 'dart:io';

import 'package:hive/src/backend/storage_backend.dart';
import 'package:hive/src/backend/vm/storage_backend_vm.dart';
import 'package:hive/src/crypto_helper.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path_helper;

class BackendManager implements BackendManagerInterface {
  @override
  Future<StorageBackend> open(String name, String path, CryptoHelper crypto,
      {@required bool crashRecovery}) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = await findHiveFileAndCleanUp(name, path);
    final lockFile = File(path_helper.join(path, '$name.lock'));

    final backend =
        StorageBackendVm(file, lockFile, crypto, crashRecovery: crashRecovery);
    await backend.open();
    return backend;
  }

  @visibleForTesting
  Future<File> findHiveFileAndCleanUp(String name, String path) async {
    final hiveFile = File(path_helper.join(path, '$name.hive'));
    final compactedFile = File(path_helper.join(path, '$name.hivec'));

    if (await hiveFile.exists()) {
      if (await compactedFile.exists()) {
        await compactedFile.delete();
      }
      return hiveFile;
    } else if (await compactedFile.exists()) {
      print('Restoring compacted file.'); // ignore: avoid_print
      return compactedFile.rename(hiveFile.path);
    } else {
      await hiveFile.create();
      return hiveFile;
    }
  }

  @override
  Future<void> deleteBox(String name, String path) async {
    await _deleteFileIfExists(File(path_helper.join(path, '$name.hive')));
    await _deleteFileIfExists(File(path_helper.join(path, '$name.hivec')));
    await _deleteFileIfExists(File(path_helper.join(path, '$name.lock')));
  }

  Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
