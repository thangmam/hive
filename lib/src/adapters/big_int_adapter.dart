import 'package:hive/hive.dart';

class BigIntAdapter extends TypeAdapter<BigInt> {
  @override
  BigInt read(BinaryReader reader) {
    final len = reader.readByte();
    final intStr = reader.readString(len);
    return BigInt.parse(intStr);
  }

  @override
  void write(BinaryWriter writer, BigInt obj) {
    final intStr = obj.toString();
    writer.writeByte(intStr.length);
    writer.writeAsciiString(intStr, writeLength: false);
  }
}
