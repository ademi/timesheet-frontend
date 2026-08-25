import 'package:get_storage/get_storage.dart';

/// Last-used NDIS catalogue category / registration-group filter values.
class NdisCatalogueFilterSnapshot {
  const NdisCatalogueFilterSnapshot({
    this.categoryNumber,
    this.registrationGroupNumber,
  });

  final String? categoryNumber;
  final String? registrationGroupNumber;
}

/// Persists [NdisSupportItemPicker] facet filters via [GetStorage].
class NdisCatalogueFilterPrefs {
  NdisCatalogueFilterPrefs({
    dynamic Function(String key)? read,
    void Function(String key, dynamic value)? write,
    void Function(String key)? remove,
    GetStorage? storage,
  })  : _read = read ?? ((key) => (storage ?? GetStorage()).read(key)),
        _write = write ?? ((key, value) => (storage ?? GetStorage()).write(key, value)),
        _remove = remove ?? ((key) => (storage ?? GetStorage()).remove(key));

  static const categoryKey = 'ndis_filter_category';
  static const regGroupKey = 'ndis_filter_reg_group';

  final dynamic Function(String key) _read;
  final void Function(String key, dynamic value) _write;
  final void Function(String key) _remove;

  NdisCatalogueFilterSnapshot load() {
    return NdisCatalogueFilterSnapshot(
      categoryNumber: _readString(categoryKey),
      registrationGroupNumber: _readString(regGroupKey),
    );
  }

  void save({
    String? categoryNumber,
    String? registrationGroupNumber,
  }) {
    _writeString(categoryKey, categoryNumber);
    _writeString(regGroupKey, registrationGroupNumber);
  }

  void clear() {
    _remove(categoryKey);
    _remove(regGroupKey);
  }

  String? _readString(String key) {
    final value = _read(key);
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _writeString(String key, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _remove(key);
      return;
    }
    _write(key, trimmed);
  }
}
