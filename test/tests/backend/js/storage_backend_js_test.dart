@TestOn('browser')

import 'dart:async' show Future;
import 'dart:html';
import 'dart:indexed_db';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/backend/js/storage_backend_js.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/change_notifier.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/crypto_helper.dart';
import 'package:test/test.dart';

import '../../frames.dart';

StorageBackendJs _getBackend({
  Database db,
  CryptoHelper crypto,
  TypeRegistry registry,
}) {
  return StorageBackendJs(db, crypto, registry);
}

Future<Database> _openDb() async {
  return window.indexedDB.open('testBox', version: 1, onUpgradeNeeded: (e) {
    final db = e.target.result as Database;
    if (!db.objectStoreNames.contains('box')) {
      db.createObjectStore('box');
    }
  });
}

ObjectStore _getStore(Database db) {
  return db.transaction('box', 'readwrite').objectStore('box');
}

Future<Database> _getDbWith(Map<String, dynamic> content) async {
  final db = await _openDb();
  final store = _getStore(db);
  await store.clear();
  content.forEach((k, v) => store.put(v, k));
  return db;
}

void main() {
  group('StorageBackendJs', () {
    test('.path', () {
      expect(_getBackend().path, null);
    });

    group('.encodeValue()', () {
      test('primitive', () {
        final values = [
          null, 11, 17.25, true, 'hello', //
          [11, 12, 13], [17.25, 17.26], [true, false], ['str1', 'str2'] //
        ];
        final backend = _getBackend();
        for (final value in values) {
          expect(backend.encodeValue(Frame('key', value)), value);
        }

        final bytes = Uint8List.fromList([1, 2, 3]);
        final buffer = backend.encodeValue(Frame('key', bytes)) as ByteBuffer;
        expect(Uint8List.view(buffer), [1, 2, 3]);
      });

      test('crypto', () {
        final backend = StorageBackendJs(null, testCrypto, testRegistry);
        var i = 0;
        for (final frame in testFrames) {
          final buffer = backend.encodeValue(frame) as ByteBuffer;
          final bytes = Uint8List.view(buffer);
          expect(bytes.sublist(28),
              [0x90, 0xA9, ...frameValuesBytesEncrypted[i]].sublist(28));
          i++;
        }
      });

      group('non primitive', () {
        test('map', () {
          final frame = Frame(0, {
            'key': Uint8List.fromList([1, 2, 3]),
            'otherKey': null
          });
          final backend = StorageBackendJs(null, null);
          final encoded =
              Uint8List.view(backend.encodeValue(frame) as ByteBuffer);

          final writer = BinaryWriterImpl(null)..write(frame.value);
          expect(encoded, [0x90, 0xA9, ...writer.toBytes()]);
        });

        test('bytes which start with signature', () {
          final frame = Frame(0, Uint8List.fromList([0x90, 0xA9, 1, 2, 3]));
          final backend = _getBackend();
          final encoded =
              Uint8List.view(backend.encodeValue(frame) as ByteBuffer);

          final writer = BinaryWriterImpl(null)..write(frame.value);
          expect(encoded, [0x90, 0xA9, ...writer.toBytes()]);
        });
      });
    });

    group('.decodeValue()', () {
      test('primitive', () {
        final backend = _getBackend();
        expect(backend.decodeValue(null), null);
        expect(backend.decodeValue(11), 11);
        expect(backend.decodeValue(17.25), 17.25);
        expect(backend.decodeValue(true), true);
        expect(backend.decodeValue('hello'), 'hello');
        expect(backend.decodeValue([11, 12, 13]), [11, 12, 13]);
        expect(backend.decodeValue([17.25, 17.26]), [17.25, 17.26]);

        final bytes = Uint8List.fromList([1, 2, 3]);
        expect(backend.decodeValue(bytes.buffer), [1, 2, 3]);
      });

      test('crypto', () {
        final crypto = CryptoHelper(Uint8List.fromList(List.filled(32, 1)));
        final backend = _getBackend(crypto: crypto, registry: testRegistry);
        var i = 0;
        for (final testFrame in testFrames) {
          final bytes = [0x90, 0xA9, ...frameValuesBytesEncrypted[i]];
          final value = backend.decodeValue(Uint8List.fromList(bytes).buffer);
          expect(value, testFrame.value);
          i++;
        }
      });

      test('non primitive', () {
        final backend = _getBackend(registry: testRegistry);
        for (final testFrame in testFrames) {
          final bytes = backend.encodeValue(testFrame);
          final value = backend.decodeValue(bytes);
          expect(value, testFrame.value);
        }
      });
    });

    test('.getKeys()', () async {
      final db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
      final backend = _getBackend(db: db);

      expect(await backend.getKeys(), ['key1', 'key2', 'key3']);
    });

    test('.getValues()', () async {
      final db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
      final backend = _getBackend(db: db);

      expect(await backend.getValues(), [1, null, 3]);
    });

    group('.initialize()', () {
      test('not lazy', () async {
        final db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
        final backend = _getBackend(db: db);

        final keystore = Keystore(null, ChangeNotifier(), null);
        expect(await backend.initialize(null, keystore, lazy: false), 0);
        expect(keystore.frames, [
          Frame('key1', 1),
          Frame('key2', null),
          Frame('key3', 3),
        ]);
      });

      test('lazy', () async {
        final db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
        final backend = _getBackend(db: db);

        final keystore = Keystore(null, ChangeNotifier(), null);
        expect(await backend.initialize(null, keystore, lazy: true), 0);
        expect(keystore.frames, [
          Frame.lazy('key1'),
          Frame.lazy('key2'),
          Frame.lazy('key3'),
        ]);
      });
    });

    test('.readValue()', () async {
      final db = await _getDbWith({'key1': 1, 'key2': null, 'key3': 3});
      final backend = _getBackend(db: db);

      expect(await backend.readValue(Frame('key1', null)), 1);
      expect(await backend.readValue(Frame('key2', null)), null);
    });

    test('.writeFrames()', () async {
      final db = await _getDbWith({});
      final backend = _getBackend(db: db);

      final frames = [Frame('key1', 123), Frame('key2', null)];
      await backend.writeFrames(frames);
      expect(frames, [Frame('key1', 123), Frame('key2', null)]);
      expect(await backend.getKeys(), ['key1', 'key2']);

      await backend.writeFrames([Frame.deleted('key1')]);
      expect(await backend.getKeys(), ['key2']);
    });

    test('.compact()', () async {
      final db = await _getDbWith({});
      final backend = _getBackend(db: db);
      expect(
        () async => backend.compact({}),
        throwsUnsupportedError,
      );
    });

    test('.clear()', () async {
      final db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
      final backend = _getBackend(db: db);
      await backend.clear();
      expect(await backend.getKeys(), []);
    });

    test('.close()', () async {
      final db = await _getDbWith({'key1': 1, 'key2': 2, 'key3': 3});
      final backend = _getBackend(db: db);
      await backend.close();

      await expectLater(() async => backend.getKeys(), throwsA(anything));
    });
  });
}
