import 'dart:typed_data';

import 'package:hive/src/adapters/big_int_adapter.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:test/test.dart';

void main() {
  group('BigIntAdapter', () {
    group('reads', () {
      test('positive BigInts', () {
        const numberStr = '123456789123456789';
        final bytes =
            Uint8List.fromList([numberStr.length, ...numberStr.codeUnits]);
        final reader = BinaryReaderImpl(bytes, null);
        expect(BigIntAdapter().read(reader), BigInt.parse(numberStr));
      });

      test('negative BigInts', () {
        const numberStr = '-123456789123456789';
        final bytes =
            Uint8List.fromList([numberStr.length, ...numberStr.codeUnits]);
        final reader = BinaryReaderImpl(bytes, null);
        expect(BigIntAdapter().read(reader), BigInt.parse(numberStr));
      });
    });

    test('writes BigInts', () {
      const numberStr = '123456789123456789';
      final writer = BinaryWriterImpl(null);
      BigIntAdapter().write(writer, BigInt.parse(numberStr));
      expect(writer.toBytes(), [numberStr.length, ...numberStr.codeUnits]);
    });
  });
}
