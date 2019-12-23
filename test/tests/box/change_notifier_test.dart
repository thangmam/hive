import 'dart:async';

import 'package:hive/hive.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/box/change_notifier.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class StreamControllerMock<T> extends Mock implements StreamController<T> {}

void main() {
  group('ChangeNotifier', () {
    test('.watch()', () async {
      final notifier = ChangeNotifier();

      final allEvents = <BoxEvent>[];
      notifier.watch().listen((e) {
        allEvents.add(e);
      });

      final filteredEvents = <BoxEvent>[];
      notifier.watch(key: 'key1').listen((e) {
        filteredEvents.add(e);
      });

      notifier.notify(Frame.deleted('key1'));
      notifier.notify(Frame('key1', 'newVal'));
      notifier.notify(Frame('key2', 'newVal2'));

      await Future.delayed(const Duration(milliseconds: 1));

      expect(allEvents, [
        BoxEvent('key1', null, deleted: true),
        BoxEvent('key1', 'newVal', deleted: false),
        BoxEvent('key2', 'newVal2', deleted: false),
      ]);

      expect(filteredEvents, [
        BoxEvent('key1', null, deleted: true),
        BoxEvent('key1', 'newVal', deleted: false),
      ]);
    });

    test('close', () async {
      final controller = StreamControllerMock<BoxEvent>();
      when(controller.close()).thenAnswer((i) => Future.value());
      final notifier = ChangeNotifier.debug(controller);

      await notifier.close();
      verify(controller.close());
    });
  });
}
