import 'package:hive/src/adapters/date_time_adapter.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('DateTimeAdapter', () {
    test('.read()', () {
      final now = DateTime.now();
      final binaryReader = BinaryReaderMock();
      when(binaryReader.readInt()).thenReturn(now.millisecondsSinceEpoch);

      final date = DateTimeAdapter().read(binaryReader);
      verify(binaryReader.readInt());
      expect(date, now.subtract(Duration(microseconds: now.microsecond)));
    });

    test('.write()', () {
      final now = DateTime.now();
      final binaryWriter = BinaryWriterMock();

      DateTimeAdapter().write(binaryWriter, now);
      verify(binaryWriter.writeInt(now.millisecondsSinceEpoch));
    });
  });
}
