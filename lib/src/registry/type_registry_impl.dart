import 'package:hive/hive.dart';
import 'package:meta/meta.dart';

class _ResolvedAdapter<T> {
  final TypeAdapter adapter;
  final int typeId;

  _ResolvedAdapter(this.adapter, this.typeId);

  bool matches(dynamic value) => value is T;
}

class TypeRegistryImpl implements TypeRegistry {
  @visibleForTesting
  static const reservedTypeIds = 32;

  final _typeAdapters = <int, _ResolvedAdapter>{};

  _ResolvedAdapter findAdapterForValue(dynamic value) {
    for (final adapter in _typeAdapters.values) {
      if (adapter.matches(value)) return adapter;
    }
    return null;
  }

  _ResolvedAdapter findAdapterForTypeId(int typeId) {
    return _typeAdapters[typeId];
  }

  @override
  void registerAdapter<T>(TypeAdapter<T> adapter, int typeId) {
    if (typeId < 0 || typeId > 223) {
      throw HiveError('TypeId $typeId not allowed.');
    }

    final updatedTypeId = typeId + reservedTypeIds;

    if (findAdapterForTypeId(updatedTypeId) != null) {
      throw HiveError('There is already a TypeAdapter for typeId $typeId.');
    }

    registerInternal(adapter, updatedTypeId);
  }

  void registerInternal<T>(TypeAdapter<T> adapter, int typeId) {
    final resolved = _ResolvedAdapter<T>(adapter, typeId);
    _typeAdapters[typeId] = resolved;
  }

  void resetAdapters() {
    _typeAdapters.clear();
  }
}
