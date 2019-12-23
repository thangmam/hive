import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/binary/frame.dart';
import 'package:hive/src/crypto_helper.dart';
import 'package:hive/src/object/hive_list_impl.dart';
import 'package:hive/src/registry/type_registry_impl.dart';
import 'package:hive/src/util/crc32.dart';
import 'package:hive/src/util/uint8_list_extension.dart';

class BinaryReaderImpl extends BinaryReader {
  final Uint8List _buffer;
  final ByteData _byteData;
  final int _bufferLength;
  final TypeRegistryImpl typeRegistry;

  int _bufferLimit;
  int _offset = 0;

  BinaryReaderImpl(this._buffer, TypeRegistry typeRegistry, [int bufferLength])
      : _byteData = ByteData.view(_buffer.buffer, _buffer.offsetInBytes),
        _bufferLength = bufferLength ?? _buffer.length,
        _bufferLimit = bufferLength ?? _buffer.length,
        typeRegistry = typeRegistry as TypeRegistryImpl;

  @override
  int get availableBytes => _bufferLimit - _offset;

  @override
  int get usedBytes => _offset;

  void _limitAvailableBytes(int bytes) {
    _requireBytes(bytes);
    _bufferLimit = _offset + bytes;
  }

  void _resetLimit() {
    _bufferLimit = _bufferLength;
  }

  void _requireBytes(int bytes) {
    if (_offset + bytes > _bufferLimit) {
      throw RangeError('Not enough bytes available.');
    }
  }

  @override
  void skip(int bytes) {
    _requireBytes(bytes);
    _offset += bytes;
  }

  @override
  int readByte() {
    _requireBytes(1);
    return _buffer[_offset++];
  }

  @override
  Uint8List viewBytes(int bytes) {
    _requireBytes(bytes);
    _offset += bytes;
    return _buffer.view(_offset - bytes, bytes);
  }

  @override
  Uint8List peekBytes(int bytes) {
    _requireBytes(bytes);
    return _buffer.view(_offset, bytes);
  }

  @override
  int readWord() {
    _requireBytes(2);
    return _buffer[_offset++] | _buffer[_offset++] << 8;
  }

  @override
  int readInt32() {
    _requireBytes(4);
    _offset += 4;
    return _byteData.getInt32(_offset - 4, Endian.little);
  }

  @override
  int readUint32() {
    _requireBytes(4);
    _offset += 4;
    return _buffer.readUint32(_offset - 4);
  }

  int peekUint32() {
    _requireBytes(4);
    return _buffer.readUint32(_offset);
  }

  @override
  int readInt() {
    return readDouble().toInt();
  }

  @override
  double readDouble() {
    _requireBytes(8);
    final value = _byteData.getFloat64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  @override
  bool readBool() {
    _requireBytes(1);
    return _buffer[_offset++] > 0;
  }

  @override
  String readString(
      [int byteCount,
      Converter<List<int>, String> decoder = BinaryReader.utf8Decoder]) {
    byteCount ??= readUint32();
    final view = viewBytes(byteCount);
    return decoder.convert(view);
  }

  @override
  String readAsciiString([int length]) {
    length ??= readUint32();
    final view = viewBytes(length);
    final str = String.fromCharCodes(view);
    return str;
  }

  @override
  Uint8List readByteList([int length]) {
    length ??= readUint32();
    _requireBytes(length);
    final byteList = _buffer.sublist(_offset, _offset + length);
    _offset += length;
    return byteList;
  }

  @override
  List<int> readIntList([int length]) {
    length ??= readUint32();
    _requireBytes(length * 8);
    final list = <int>[]..length = length;
    for (var i = 0; i < length; i++) {
      list[i] = _byteData.getFloat64(_offset, Endian.little).toInt();
      _offset += 8;
    }
    return list;
  }

  @override
  List<double> readDoubleList([int length]) {
    length ??= readUint32();
    _requireBytes(length * 8);
    final list = <double>[]..length = length;
    for (var i = 0; i < length; i++) {
      list[i] = _byteData.getFloat64(_offset, Endian.little);
      _offset += 8;
    }
    return list;
  }

  @override
  List<bool> readBoolList([int length]) {
    length ??= readUint32();
    _requireBytes(length);
    final list = <bool>[]..length = length;
    for (var i = 0; i < length; i++) {
      list[i] = _buffer[_offset++] > 0;
    }
    return list;
  }

  @override
  List<String> readStringList(
      [int length,
      Converter<List<int>, String> decoder = BinaryReader.utf8Decoder]) {
    length ??= readUint32();
    final list = <String>[]..length = length;
    for (var i = 0; i < length; i++) {
      list[i] = readString(null, decoder);
    }
    return list;
  }

  @override
  List readList([int length]) {
    length ??= readUint32();
    final list = <dynamic>[]..length = length;
    for (var i = 0; i < length; i++) {
      list[i] = read();
    }
    return list;
  }

  @override
  Map readMap([int length]) {
    length ??= readUint32();
    final map = <dynamic, dynamic>{};
    for (var i = 0; i < length; i++) {
      final key = read();
      final value = read();
      map[key] = value;
    }
    return map;
  }

  dynamic readKey() {
    final keyType = readByte();
    if (keyType == FrameKeyType.uintT.index) {
      return readUint32();
    } else if (keyType == FrameKeyType.asciiStringT.index) {
      final keyLength = readByte();
      return readAsciiString(keyLength);
    } else {
      throw HiveError('Unsupported key type. Frame might be corrupted.');
    }
  }

  @override
  HiveList readHiveList([int length]) {
    length ??= readUint32();
    final boxNameLength = readByte();
    final boxName = readAsciiString(boxNameLength);
    final keys = List<dynamic>(length);
    for (var i = 0; i < length; i++) {
      keys[i] = readKey();
    }

    return HiveListImpl.lazy(boxName, keys);
  }

  Frame readFrame({CryptoHelper crypto, bool lazy = false, int frameOffset}) {
    if (availableBytes < 4) return null;

    final frameLength = readUint32();
    if (frameLength < 8) {
      throw HiveError(
          'This should not happen. Please open an issue on GitHub.');
    }
    if (availableBytes < frameLength - 4) return null;

    final crc = _buffer.readUint32(_offset + frameLength - 8);
    final computedCrc = Crc32.compute(
      _buffer,
      offset: _offset - 4,
      length: frameLength - 4,
      startCrc: crypto?.keyCrc ?? 0,
    );

    if (computedCrc != crc) return null;

    _limitAvailableBytes(frameLength - 8);
    Frame frame;
    final key = readKey();

    if (availableBytes == 0) {
      frame = Frame.deleted(key);
    } else if (lazy) {
      frame = Frame.lazy(key);
    } else if (crypto == null) {
      frame = Frame(key, read());
    } else {
      frame = Frame(key, readEncrypted(crypto));
    }

    frame
      ..length = frameLength
      ..offset = frameOffset;

    skip(availableBytes);
    _resetLimit();
    skip(4); // Skip CRC

    return frame;
  }

  @override
  dynamic read([int typeId]) {
    typeId ??= readByte();
    if (typeId < FrameValueType.values.length) {
      final typeEnum = FrameValueType.values[typeId];
      switch (typeEnum) {
        case FrameValueType.nullT:
          return null;
        case FrameValueType.intT:
          return readInt();
        case FrameValueType.doubleT:
          return readDouble();
        case FrameValueType.boolT:
          return readBool();
        case FrameValueType.stringT:
          return readString();
        case FrameValueType.byteListT:
          return readByteList();
        case FrameValueType.intListT:
          return readIntList();
        case FrameValueType.doubleListT:
          return readDoubleList();
        case FrameValueType.boolListT:
          return readBoolList();
        case FrameValueType.stringListT:
          return readStringList();
        case FrameValueType.listT:
          return readList();
        case FrameValueType.mapT:
          return readMap();
        case FrameValueType.hiveListT:
          return readHiveList();
      }
    } else {
      final resolved = typeRegistry.findAdapterForTypeId(typeId);
      if (resolved == null) {
        throw HiveError('Cannot read, unknown typeId: $typeId. '
            'Did you forget to register an adapter?');
      }
      return resolved.adapter.read(this);
    }
  }

  dynamic readEncrypted(CryptoHelper crypto) {
    final encryptedBytes = viewBytes(availableBytes);
    final decryptedBytes = crypto.decrypt(encryptedBytes);
    final valueReader = BinaryReaderImpl(decryptedBytes, typeRegistry);
    return valueReader.read();
  }
}
