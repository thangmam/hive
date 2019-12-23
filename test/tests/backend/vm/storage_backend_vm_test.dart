@TestOn('vm')

import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/backend/vm/read_write_sync.dart';
import 'package:hive/src/backend/vm/storage_backend_vm.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/crypto_helper.dart';
import 'package:hive/src/io/frame_io_helper.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../common.dart';
import '../../frames.dart';
import '../../mocks.dart';

class FrameIoHelperMock extends Mock implements FrameIoHelper {}

const testMap = {
  'SomeKey': 123,
  'AnotherKey': ['Just', 456, 'a', 333, 'List'],
  'Random Double list': [1.0, 2.0, 10.0, double.infinity],
  'Unicode:': '👋',
  'Null': null,
  'LastKey': true,
};

Uint8List getFrameBytes(Iterable<Frame> frames) {
  final writer = BinaryWriterImpl(testRegistry);
  for (final frame in frames) {
    writer.writeFrame(frame);
  }
  return writer.toBytes();
}

StorageBackendVm _getBackend({
  File file,
  File lockFile,
  bool crashRecovery = false,
  CryptoHelper crypto,
  FrameIoHelper ioHelper,
  TypeRegistry registry,
  ReadWriteSync sync,
  RandomAccessFile readRaf,
  RandomAccessFile writeRaf,
}) {
  return StorageBackendVm.debug(
    file ?? FileMock(),
    lockFile ?? FileMock(),
    crypto,
    ioHelper ?? FrameIoHelperMock(),
    sync ?? ReadWriteSync(),
    crashRecovery: crashRecovery,
  )
    ..readRaf = readRaf
    ..writeRaf = writeRaf;
}

void main() {
  group('StorageBackendVm', () {
    test('.path returns path for of open box file', () {
      final file = File('some/path');
      final backend = _getBackend(file: file);
      expect(backend.path, 'some/path');
    });

    test('.supportsCompaction is true', () {
      final backend = _getBackend();
      expect(backend.supportsCompaction, true);
    });

    group('.open()', () {
      test('readFile & writeFile', () async {
        final file = FileMock();
        final readRaf = RAFMock();
        final writeRaf = RAFMock();
        when(file.open()).thenAnswer((i) => Future.value(readRaf));
        when(file.open(mode: FileMode.writeOnlyAppend))
            .thenAnswer((i) => Future.value(writeRaf));

        final backend = _getBackend(file: file);
        await backend.open();
        expect(backend.readRaf, readRaf);
        expect(backend.writeRaf, writeRaf);
      });

      test('writeOffset', () async {
        final file = FileMock();
        final writeFile = RAFMock();
        when(file.open(mode: FileMode.writeOnlyAppend))
            .thenAnswer((i) => Future.value(writeFile));
        when(writeFile.length()).thenAnswer((i) => Future.value(123));

        final backend = _getBackend(file: file);
        await backend.open();
        expect(backend.writeOffset, 123);
      });
    });

    group('.initialize()', () {
      File getLockFile() {
        final lockFileMock = FileMock();
        when(lockFileMock.open(mode: FileMode.write))
            .thenAnswer((i) => Future.value(RAFMock()));
        return lockFileMock;
      }

      FrameIoHelper getFrameIoHelper(int recoveryOffset) {
        final helper = FrameIoHelperMock();
        when(helper.framesFromFile(any, any, any, any)).thenAnswer((i) {
          return Future.value(recoveryOffset);
        });
        when(helper.keysFromFile(any, any, any)).thenAnswer((i) {
          return Future.value(recoveryOffset);
        });
        return helper;
      }

      void runTests({bool lazy}) {
        test('opens lock file and aquires lock', () async {
          final lockFile = FileMock();
          final lockRaf = RAFMock();
          when(lockFile.open(mode: FileMode.write))
              .thenAnswer((i) => Future.value(lockRaf));

          final backend = _getBackend(
            lockFile: lockFile,
            ioHelper: getFrameIoHelper(-1),
          );

          await backend.initialize(null, KeystoreMock(), lazy: lazy);
          verify(lockRaf.lock());
        });

        test('recoveryOffset with crash recovery', () async {
          final writeRaf = RAFMock();
          final backend = _getBackend(
            lockFile: getLockFile(),
            ioHelper: getFrameIoHelper(20),
            crashRecovery: true,
            writeRaf: writeRaf,
          );

          await backend.initialize(null, KeystoreMock(), lazy: lazy);
          verify(writeRaf.truncate(20));
        });

        test('recoveryOffset without crash recovery', () async {
          final backend = _getBackend(
            lockFile: getLockFile(),
            ioHelper: getFrameIoHelper(20),
            crashRecovery: false,
          );

          await expectLater(
              () => backend.initialize(null, KeystoreMock(), lazy: lazy),
              throwsHiveError('corrupted'));
        });
      }

      group('(not lazy)', () {
        runTests(lazy: false);
      });

      group('(lazy)', () {
        runTests(lazy: true);
      });
    });

    group('.readValue()', () {
      test('reads value with offset', () async {
        final frameBytes = getFrameBytes([Frame('test', 123)]);
        final readRaf = await getTempRaf([1, 2, 3, 4, 5, ...frameBytes]);

        final backend = _getBackend(readRaf: readRaf);
        final value = await backend.readValue(
          Frame('test', 123, length: frameBytes.length, offset: 5),
        );
        expect(value, 123);

        await readRaf.close();
      });

      test('throws exception when frame cannot be read', () async {
        final readRaf = await getTempRaf([1, 2, 3, 4, 5]);
        final backend = _getBackend(readRaf: readRaf);

        final frame = Frame('test', 123, length: frameBytes.length, offset: 0);
        await expectLater(
            () => backend.readValue(frame), throwsHiveError('corrupted'));

        await readRaf.close();
      });
    });

    group('.writeFrames()', () {
      test('writes bytes', () async {
        final frames = [Frame('key1', 'value'), Frame('key2', null)];
        final bytes = getFrameBytes(frames);

        final writeRaf = RAFMock();
        final backend = _getBackend(writeRaf: writeRaf);

        await backend.writeFrames(frames);
        verify(writeRaf.writeFrom(bytes));
      });

      test('updates offsets', () async {
        final frames = [Frame('key1', 'value'), Frame('key2', null)];

        final writeRaf = RAFMock();
        final backend = _getBackend(writeRaf: writeRaf);
        backend.writeOffset = 5;

        await backend.writeFrames(frames);
        expect(frames, [
          Frame('key1', 'value', length: 24, offset: 5),
          Frame('key2', null, length: 15, offset: 29),
        ]);
        expect(backend.writeOffset, 44);
      });

      test('resets writeOffset on error', () async {
        final writeRaf = RAFMock();
        when(writeRaf.writeFrom(any)).thenThrow('error');
        final backend = _getBackend(writeRaf: writeRaf);
        backend.writeOffset = 123;

        await expectLater(() => backend.writeFrames([Frame('key1', 'value')]),
            throwsA(anything));
        verify(writeRaf.setPosition(123));
        expect(backend.writeOffset, 123);
      });
    });

    /*group('.compact()', () {
      //TODO improve this test
      test('check compaction', () async {
        final bytes = BytesBuilder();
        final comparisonBytes = BytesBuilder();
        final entries = <String, Frame>{};

        void addFrame(String key, dynamic val, [bool keep = false]) {
          final frameBytes = Frame(key, val).toBytes(null, null);
          if (keep) {
            entries[key] = Frame(key, val,
                length: frameBytes.length, offset: bytes.length);
            comparisonBytes.add(frameBytes);
          } else {
            entries.remove(key);
          }
          bytes.add(frameBytes);
        }

        for (final i = 0; i < 1000; i++) {
          for (final key in testMap.keys) {
            addFrame(key, testMap[key]);
            addFrame(key, null);
          }
        }

        for (final key in testMap.keys) {
          addFrame(key, 12345);
          addFrame(key, null);
          addFrame(key, 'This is a test');
          addFrame(key, testMap[key], true);
        }

        final boxFile = await getTempFile();
        await boxFile.writeAsBytes(bytes.toBytes());

        final syncedFile = SyncedFile(boxFile.path);
        await syncedFile.open();
        final backend = StorageBackendVm(syncedFile, null);

        await backend.compact(entries.values);

        final compactedBytes = await File(backend.path).readAsBytes();
        expect(compactedBytes, comparisonBytes.toBytes());

        await backend.close();
      });

      test('throws error if corrupted', () async {
        final bytes = BytesBuilder();
        final boxFile = await getTempFile(); 
        final syncedFile = SyncedFile(boxFile.path);
        await syncedFile.open();

        final box = BoxImplVm(
            HiveImpl(), path.basename(boxFile.path), BoxOptions(), syncedFile);
        await box.put('test', true);
        await box.put('test2', 'hello');
        await box.put('test', 'world');

        await syncedFile.truncate(await boxFile.length() - 1);

        expect(() => box.compact(), throwsHiveError('unexpected eof'));
      });
    });*/

    test('.clear()', () async {
      final writeRaf = RAFMock();
      final backend = _getBackend(writeRaf: writeRaf);
      backend.writeOffset = 111;

      await backend.clear();
      verify(writeRaf.truncate(0));
      verify(writeRaf.setPosition(0));
      expect(backend.writeOffset, 0);
    });

    test('.close()', () async {
      final readRaf = RAFMock();
      final writeRaf = RAFMock();
      final lockRaf = RAFMock();
      final lockFile = FileMock();

      final backend = _getBackend(
        lockFile: lockFile,
        readRaf: readRaf,
        writeRaf: writeRaf,
      );
      backend.lockRaf = lockRaf;

      await backend.close();
      verifyInOrder([
        readRaf.close(),
        writeRaf.close(),
        lockRaf.close(),
        lockFile.delete(),
      ]);
    });

    test('.deleteFromDisk()', () async {
      final readRaf = RAFMock();
      final writeRaf = RAFMock();
      final lockRaf = RAFMock();
      final lockFile = FileMock();
      final file = FileMock();

      final backend = _getBackend(
        file: file,
        lockFile: lockFile,
        readRaf: readRaf,
        writeRaf: writeRaf,
      );
      backend.lockRaf = lockRaf;

      await backend.deleteFromDisk();
      verifyInOrder([
        readRaf.close(),
        writeRaf.close(),
        lockRaf.close(),
        lockFile.delete(),
        file.delete()
      ]);
    });
  });
}
