import 'package:hive/src/util/crc32.dart';
import 'package:test/test.dart';

void main() {
  group('Crc32', () {
    test('compute', () {
      expect(Crc32.compute([]), equals(0));
      expect(Crc32.compute('123456789'.codeUnits), equals(0xcbf43926));

      final crc = Crc32.compute('12345'.codeUnits);
      expect(
          Crc32.compute('6789'.codeUnits, startCrc: crc), equals(0xcbf43926));
    });
  });
}
