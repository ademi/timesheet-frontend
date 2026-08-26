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
///
/// Keys are scoped by [tenantId] when set so filters do not leak across
/// tenants on the same device.
class NdisCatalogueFilterPrefs {
  NdisCatalogueFilterPrefs({
    this.tenantId,
    dynamic Function(String key)? read,
    void Function(String key, dynamic value)? write,
    void Function(String key)? remove,
    GetStorage? storage,
  })  : _read = read ?? ((key) => (storage ?? GetStorage()).read(key)),
        _write = write ?? ((key, value) => (storage ?? GetStorage()).write(key, value)),
        _remove = remove ?? ((key) => (storage ?? GetStorage()).remove(key));

  static const categoryKeyBase = 'ndis_filter_category';
  static const regGroupKeyBase = 'ndis_filter_reg_group';

  /// Legacy global keys (pre-tenant scoping); kept for [clear] / migration.
  static const categoryKey = categoryKeyBase;
  static const regGroupKey = regGroupKeyBase;

  final String? tenantId;
  final dynamic Function(String key) _read;
  final void Function(String key, dynamic value) _write;
  final void Function(String key) _remove;

  String get _categoryKey {
    final id = tenantId?.trim();
    if (id == null || id.isEmpty) return categoryKeyBase;
    return '${categoryKeyBase}_$id';
  }

  String get _regGroupKey {
    final id = tenantId?.trim();
    if (id == null || id.isEmpty) return regGroupKeyBase;
    return '${regGroupKeyBase}_$id';
  }

  NdisCatalogueFilterSnapshot load() {
    return NdisCatalogueFilterSnapshot(
      categoryNumber: _readString(_categoryKey),
      registrationGroupNumber: _readString(_regGroupKey),
    );
  }

  void save({
    String? categoryNumber,
    String? registrationGroupNumber,
  }) {
    _writeString(_categoryKey, categoryNumber);
    _writeString(_regGroupKey, registrationGroupNumber);
  }

  void clear() {
    _remove(_categoryKey);
    _remove(_regGroupKey);
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
