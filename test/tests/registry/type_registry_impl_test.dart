import 'package:hive/hive.dart';
import 'package:hive/src/registry/type_registry_impl.dart';
import 'package:test/test.dart';

import '../common.dart';

class TestAdapter extends TypeAdapter<int> {
  @override
  int read(BinaryReader reader) {
    return 5;
  }

  @override
  void write(BinaryWriter writer, int obj) {}
}

class TestAdapter2 extends TypeAdapter<int> {
  @override
  int read(BinaryReader reader) {
    return 5;
  }

  @override
  void write(BinaryWriter writer, int obj) {}
}

void main() {
  group('TypeRegistryImpl', () {
    group('.registerAdapter()', () {
      test('register', () {
        final registry = TypeRegistryImpl();
        final adapter = TestAdapter();
        registry.registerAdapter(adapter, 0);

        final resolved = registry.findAdapterForValue(123);
        expect(resolved.typeId, 32);
        expect(resolved.adapter, adapter);
      });

      test('unsupported typeId', () {
        final registry = TypeRegistryImpl();
        expect(() => registry.registerAdapter(TestAdapter(), -1),
            throwsHiveError('not allowed'));
        expect(() => registry.registerAdapter(TestAdapter(), 224),
            throwsHiveError('not allowed'));
      });

      test('duplicate typeId', () {
        final registry = TypeRegistryImpl();
        registry.registerAdapter(TestAdapter(), 0);
        expect(() => registry.registerAdapter(TestAdapter(), 0),
            throwsHiveError('already a TypeAdapter for typeId'));
      });
    });

    test('.findAdapterForTypeId()', () {
      final registry = TypeRegistryImpl();
      final adapter = TestAdapter();
      registry.registerAdapter(adapter, 0);

      final resolvedAdapter = registry.findAdapterForTypeId(32);
      expect(resolvedAdapter.typeId, 32);
      expect(resolvedAdapter.adapter, adapter);
    });

    group('.findAdapterForValue()', () {
      test('finds adapter', () {
        final registry = TypeRegistryImpl();
        final adapter = TestAdapter();
        registry.registerAdapter(adapter, 0);

        final resolvedAdapter = registry.findAdapterForValue(123);
        expect(resolvedAdapter.typeId, 32);
        expect(resolvedAdapter.adapter, adapter);
      });

      test('returns first matching adapter', () {
        final registry = TypeRegistryImpl();
        final adapter1 = TestAdapter();
        final adapter2 = TestAdapter();
        registry.registerAdapter(adapter1, 0);
        registry.registerAdapter(adapter2, 1);

        final resolvedAdapter = registry.findAdapterForValue(123);
        expect(resolvedAdapter.typeId, 32);
        expect(resolvedAdapter.adapter, adapter1);
      });
    });

    test('.resetAdapters()', () {
      final registry = TypeRegistryImpl();
      final adapter = TestAdapter();
      registry.registerAdapter(adapter, 0);

      registry.resetAdapters();
      expect(registry.findAdapterForValue(123), null);
    });
  });
}
