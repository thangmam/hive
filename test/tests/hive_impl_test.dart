@TestOn('vm')

import 'dart:io';

import 'package:hive/src/adapters/date_time_adapter.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  group('HiveImpl', () {
    Future<HiveImpl> initHive() async {
      final tempDir = await getTempDir();
      final hive = HiveImpl();
      hive.init(tempDir.path);
      return hive;
    }

    test('.init()', () {
      final hive = HiveImpl();

      hive.init('MYPATH');
      expect(hive.homePath, 'MYPATH');

      hive.init('OTHERPATH');
      expect(hive.homePath, 'OTHERPATH');

      expect(
        hive.findAdapterForValue(DateTime.now()).adapter,
        isA<DateTimeAdapter>(),
      );
      expect(hive.findAdapterForTypeId(16).adapter, isA<DateTimeAdapter>());
    });

    group('.openBox()', () {
      group('box already open', () {
        test('opened box is returned if it exists', () async {
          final hive = await initHive();

          final testBox = await hive.openBox('TESTBOX');
          final testBox2 = await hive.openBox('testBox');
          expect(testBox == testBox2, true);

          await hive.close();
        });

        test('throw HiveError if opened box is lazy', () async {
          final hive = await initHive();

          await hive.openLazyBox('LAZYBOX');
          await expectLater(
            () => hive.openBox('lazyBox'),
            throwsHiveError('is already open and of type LazyBox<dynamic>'),
          );

          await hive.close();
        });
      });
    });

    group('.openLazyBox()', () {
      group('box already open', () {
        test('opened box is returned if it exists', () async {
          final hive = await initHive();

          final testBox = await hive.openLazyBox('TESTBOX');
          final testBox2 = await hive.openLazyBox('testBox');
          expect(testBox == testBox2, true);

          await hive.close();
        });

        test('throw HiveError if opened box is not lazy', () async {
          final hive = await initHive();

          await hive.openBox('LAZYBOX');
          await expectLater(
            () => hive.openLazyBox('lazyBox'),
            throwsHiveError('is already open and of type Box<dynamic>'),
          );

          await hive.close();
        });
      });
    });

    group('.box()', () {
      test('returns already opened box', () async {
        final hive = await initHive();

        final box = await hive.openBox('TESTBOX');
        expect(hive.box('testBox'), box);
        expect(() => hive.box('other'), throwsHiveError('not found'));

        await hive.close();
      });

      test('throws HiveError if box type does not match', () async {
        final hive = await initHive();

        await hive.openBox<int>('INTBOX');
        expect(
          () => hive.box('intBox'),
          throwsHiveError('is already open and of type Box<int>'),
        );

        await hive.openBox('DYNAMICBOX');
        expect(
          () => hive.box<int>('dynamicBox'),
          throwsHiveError('is already open and of type Box<dynamic>'),
        );

        await hive.openLazyBox('LAZYBOX');
        expect(
          () => hive.box('lazyBox'),
          throwsHiveError('is already open and of type LazyBox<dynamic>'),
        );

        await hive.close();
      });
    });

    group('.lazyBox()', () {
      test('returns already opened box', () async {
        final hive = await initHive();

        final box = await hive.openLazyBox('TESTBOX');
        expect(hive.lazyBox('testBox'), box);
        expect(() => hive.lazyBox('other'), throwsHiveError('not found'));

        await hive.close();
      });

      test('throws HiveError if box type does not match', () async {
        final hive = await initHive();

        await hive.openLazyBox<int>('INTBOX');
        expect(
          () => hive.lazyBox('intBox'),
          throwsHiveError('is already open and of type LazyBox<int>'),
        );

        await hive.openLazyBox('DYNAMICBOX');
        expect(
          () => hive.lazyBox<int>('dynamicBox'),
          throwsHiveError('is already open and of type LazyBox<dynamic>'),
        );

        await hive.openBox('BOX');
        expect(
          () => hive.lazyBox('box'),
          throwsHiveError('is already open and of type Box<dynamic>'),
        );

        await hive.close();
      });
    });

    test('isBoxOpen()', () async {
      final hive = await initHive();

      await hive.openBox('testBox');

      expect(hive.isBoxOpen('testBox'), true);
      expect(hive.isBoxOpen('nonExistingBox'), false);

      await hive.close();
    });

    test('.close()', () async {
      final hive = await initHive();

      final box1 = await hive.openBox('box1');
      final box2 = await hive.openBox('box2');
      expect(box1.isOpen, true);
      expect(box2.isOpen, true);

      await hive.close();
      expect(box1.isOpen, false);
      expect(box2.isOpen, false);
    });

    test('.generateSecureKey()', () {
      final hive = HiveImpl();

      final key1 = hive.generateSecureKey();
      final key2 = hive.generateSecureKey();

      expect(key1.length, 32);
      expect(key2.length, 32);
      expect(key1, isNot(key2));
    });

    group('.deleteBoxFromDisk()', () {
      test('deletes box files', () async {
        final hive = await initHive();

        final box1 = await hive.openBox('testBox1');
        await box1.put('key', 'value');
        final box1File = File(box1.path);

        await hive.deleteBoxFromDisk('testBox1');
        expect(await box1File.exists(), false);
        expect(hive.isBoxOpen('testBox1'), false);

        await hive.close();
      });

      test('does nothing if files do not exist', () async {
        final hive = await initHive();
        await hive.deleteBoxFromDisk('testBox1');
        await hive.close();
      });
    });

    test('.deleteFromDisk()', () async {
      final hive = await initHive();

      final box1 = await hive.openBox('testBox1');
      await box1.put('key', 'value');
      final box1File = File(box1.path);

      final box2 = await hive.openBox('testBox2');
      await box2.put('key', 'value');
      final box2File = File(box1.path);

      await hive.deleteFromDisk();
      expect(await box1File.exists(), false);
      expect(await box2File.exists(), false);
      expect(hive.isBoxOpen('testBox1'), false);
      expect(hive.isBoxOpen('testBox2'), false);

      await hive.close();
    });
  });
}
