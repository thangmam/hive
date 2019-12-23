import 'package:hive/hive.dart';
import 'package:hive/src/backend/storage_backend.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/change_notifier.dart';
import 'package:hive/src/box/keystore.dart';
import 'package:hive/src/box/lazy_box_impl.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../mocks.dart';

LazyBoxImpl _getBox({
  String name,
  HiveImpl hive,
  Keystore keystore,
  CompactionStrategy cStrategy,
  StorageBackend backend,
}) {
  final box = LazyBoxImpl(
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
  group('LazyBoxImpl', () {
    group('.get()', () {
      test('returns defaultValue if key does not exist', () async {
        final backend = BackendMock();
        final box = _getBox(backend: backend);

        expect(await box.get('someKey'), null);
        expect(await box.get('otherKey', defaultValue: -12), -12);
        verifyZeroInteractions(backend);
      });

      test('reads value from backend', () async {
        final backend = BackendMock();
        when(backend.readValue(any)).thenAnswer((i) async => 'testVal');

        final box = _getBox(backend: backend);
        final frame = Frame.lazy('testKey', length: 123, offset: 456);
        box.keystore.insert(frame);

        expect(await box.get('testKey'), 'testVal');
        verify(backend.readValue(frame));
      });
    });

    test('.getAt()', () async {
      final keystore = Keystore.debug(frames: [
        Frame.lazy(0),
        Frame.lazy('a'),
      ]);
      final backend = BackendMock();
      when(backend.readValue(any)).thenAnswer((i) {
        return Future.value('A');
      });
      final box = _getBox(keystore: keystore, backend: backend);

      expect(await box.getAt(1), 'A');
    });

    group('.putAll()', () {
      test('values', () async {
        final backend = BackendMock();
        final keystore = KeystoreMock();
        when(keystore.containsKey(any)).thenReturn(false);

        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await box.putAll({'key1': 'value1', 'key2': 'value2'});
        verifyInOrder([
          backend.writeFrames([
            Frame('key1', 'value1'),
            Frame('key2', 'value2'),
          ]),
          keystore.insert(Frame.lazy('key1')),
          keystore.insert(Frame.lazy('key2')),
        ]);
      });

      test('handles exceptions', () async {
        final backend = BackendMock();
        final keystore = KeystoreMock();

        when(backend.writeFrames(any)).thenThrow('Some error');
        when(keystore.containsKey(any)).thenReturn(true);

        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await expectLater(
          () => box.putAll({'key1': 'value1', 'key2': 'value2'}),
          throwsA(anything),
        );
        verifyInOrder([
          backend.writeFrames([
            Frame('key1', 'value1'),
            Frame('key2', 'value2'),
          ]),
        ]);
        verifyNoMoreInteractions(keystore);
      });
    });

    group('.deleteAll()', () {
      test('does nothing when deleting non existing keys', () async {
        final backend = BackendMock();
        final keystore = KeystoreMock();
        when(keystore.containsKey(any)).thenReturn(false);
        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await box.deleteAll(['key1', 'key2', 'key3']);
        verifyZeroInteractions(backend);
      });

      test('delete keys', () async {
        final backend = BackendMock();
        final keystore = KeystoreMock();
        when(keystore.containsKey(any)).thenReturn(true);

        final box = _getBox(
          backend: backend,
          keystore: keystore,
        );

        await box.deleteAll(['key1', 'key2']);
        verifyInOrder([
          keystore.containsKey('key1'),
          keystore.containsKey('key2'),
          backend.writeFrames([Frame.deleted('key1'), Frame.deleted('key2')]),
          keystore.insert(Frame.deleted('key1')),
          keystore.insert(Frame.deleted('key2')),
        ]);
      });
    });
  });
}
