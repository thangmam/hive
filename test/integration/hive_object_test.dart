import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:test/test.dart';

import 'integration.dart';

class _TestObject extends HiveObject {
  String name;

  _TestObject(this.name);

  @override
  bool operator ==(dynamic other) => other is _TestObject && other.name == name;
}

class _TestObjectAdapter extends TypeAdapter<_TestObject> {
  @override
  _TestObject read(BinaryReader reader) {
    return _TestObject(reader.readString());
  }

  @override
  void write(BinaryWriter writer, _TestObject obj) {
    writer.writeString(obj.name);
  }
}

Future _performTest(bool lazy) async {
  final hive = HiveImpl();
  hive.registerAdapter(_TestObjectAdapter(), 0);
  var box = await openBox(lazy: lazy, hive: hive);

  var obj1 = _TestObject('test1');
  await box.add(obj1);
  expect(obj1.key, 0);

  var obj2 = _TestObject('test2');
  box.put('someKey', obj2);
  expect(obj2.key, 'someKey');

  box = await box.reopen();
  obj1 = await await box.get(0) as _TestObject;
  obj2 = await await box.get('someKey') as _TestObject;
  expect(obj1.name, 'test1');
  expect(obj2.name, 'test2');

  obj1.name = 'test1 updated';
  await obj1.save();
  await obj2.delete();

  box = await box.reopen();
  obj1 = await await box.get(0) as _TestObject;
  obj2 = await await box.get('someKey') as _TestObject;
  expect(obj1.name, 'test1 updated');
  expect(obj2, null);

  await box.close();
}

void main() {
  group('use HiveObject to update and delete entries', () {
    test('normal box', () => _performTest(false));

    test('lazy box', () => _performTest(true));
  }, timeout: longTimeout);
}
