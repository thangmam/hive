import 'package:hive/hive.dart';
import 'package:hive/src/backend/storage_backend.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/box_impl.dart';
import 'package:hive/src/box/change_notifier.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../mocks.dart';

BoxImpl _getBox({
  String name,
  HiveImpl hive,
  Keystore keystore,
  CompactionStrategy cStrategy,
  StorageBackend backend,
}) {
  final box = BoxImpl(
    hive ?? HiveImpl(),
    name ?? 'testBox',
    null,
    cStrategy ?? (total, deleted) => false,
    backend ?? BackendMock(),
  );
  box.keystore = keystore ?? Keystore(box, ChangeNotifier(), null);
  return box;
}

void main() {
  group('BoxImpl', () {
    test('.values', () {
      final keystore = Keystore.debug(frames: [
        Frame(0, 123),
        Frame('key1', 'value1'),
        Frame(1, null),
      ]);
      final box = _getBox(keystore: keystore);

      expect(box.values, [123, null, 'value1']);
    });

    group('.get()', () {
      test('returns defaultValue if key does not exist', () {
        final backend = BackendMock();
        final box = _getBox(backend: backend);

        expect(box.get('someKey'), null);
        expect(box.get('otherKey', defaultValue: -12), -12);
        verifyZeroInteractions(backend);
      });

      test('returns cached value if it exists', () {
        final backend = BackendMock();
        final box = _getBox(
          backend: backend,
          keystore: Keystore.debug(frames: [
            Frame('testKey', 'testVal'),
            Frame(123, 456),
          ]),
        );

        expect(box.get('testKey'), 'testVal');
        expect(box.get(123), 456);
        verifyZeroInteractions(backend);
      });
    });

    test('.getAt() returns value at given index', () {
      final keystore =
          Keystore.debug(frames: [Frame(0, 'zero'), Frame('a', 'A')]);
      final box = _getBox(keystore: keystore);

      expect(box.getAt(0), 'zero');
      expect(box.getAt(1), 'A');
    });

    group('.putAll()', () {
      test('values', () async {
        final backend = BackendMock();
        final keystore = KeystoreMock();
        when(keystore.frames).thenReturn([Frame('keystoreFrames', 123)]);
        when(keystore.beginTransaction(any)).thenReturn(true);
        when(backend.supportsCompaction).thenReturn(true);

        final box = _getBox(
          keystore: keystore,
          backend: backend,
          cStrategy: (a, b) => true,
        );

        await box.putAll({'key1': 'value1', 'key2': 'value2'});
        final frames = [Frame('key1', 'value1'), Frame('key2', 'value2')];
        verifyInOrder([
          keystore.beginTransaction(frames),
          backend.writeFrames(frames),
          keystore.commitTransaction(),
          backend.compact([Frame('keystoreFrames', 123)]),
        ]);
      });

      test('does nothing if no frames are provided', () async {
        final backend = BackendMock();
        final keystore = KeystoreMock();
        when(keystore.beginTransaction([])).thenReturn(false);

        final box = _getBox(backend: backend, keystore: keystore);

        await box.putAll({});
        verify(keystore.beginTransaction([]));
        verifyZeroInteractions(backend);
      });

      test('handles exceptions', () async {
        final backend = BackendMock();
        final keystore = KeystoreMock();

        when(backend.writeFrames(any)).thenThrow('Some error');
        when(keystore.beginTransaction(any)).thenReturn(true);

        final box = _getBox(backend: backend, keystore: keystore);

        await expectLater(
          () => box.putAll({'key1': 'value1', 'key2': 'value2'}),
          throwsA(anything),
        );
        final frames = [Frame('key1', 'value1'), Frame('key2', 'value2')];
        verifyInOrder([
          keystore.beginTransaction(frames),
          backend.writeFrames(frames),
          keystore.cancelTransaction(),
        ]);
      });
    });

    group('.deleteAll()', () {
      test('do nothing when deleting non existing keys', () async {
        final backend = BackendMock();
        final box = _getBox(backend: backend);

        await box.deleteAll(['key1', 'key2', 'key3']);
        verifyZeroInteractions(backend);
      });

      test('delete keys', () async {
        final backend = BackendMock();
        final keystore = KeystoreMock();
        when(backend.supportsCompaction).thenReturn(true);
        when(keystore.beginTransaction(any)).thenReturn(true);
        when(keystore.containsKey(any)).thenReturn(true);

        final box = _getBox(
          backend: backend,
          keystore: keystore,
          cStrategy: (a, b) => true,
        );

        await box.deleteAll(['key1', 'key2']);
        final frames = [Frame.deleted('key1'), Frame.deleted('key2')];
        verifyInOrder([
          keystore.containsKey('key1'),
          keystore.containsKey('key2'),
          keystore.beginTransaction(frames),
          backend.writeFrames(frames),
          keystore.commitTransaction(),
          backend.compact(any),
        ]);
      });
    });

    test('.toMap()', () {
      final box = _getBox(
        keystore: Keystore.debug(frames: [
          Frame('key1', 1),
          Frame('key2', 2),
          Frame('key4', 444),
        ]),
      );
      expect(box.toMap(), {'key1': 1, 'key2': 2, 'key4': 444});
    });
  });
}
