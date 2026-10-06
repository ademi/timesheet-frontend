import 'package:get_storage/get_storage.dart';

/// Most-recently selected client ids (MRU), scoped by optional [tenantId].
class RecentClientsPrefs {
  RecentClientsPrefs({
    this.tenantId,
    dynamic Function(String key)? read,
    void Function(String key, dynamic value)? write,
    void Function(String key)? remove,
    GetStorage? storage,
    this.maxIds = 12,
  }) : _read = read ?? ((key) => (storage ?? GetStorage()).read(key)),
       _write =
           write ??
           ((key, value) => (storage ?? GetStorage()).write(key, value)),
       _remove = remove ?? ((key) => (storage ?? GetStorage()).remove(key));

  static const keyBase = 'recent_client_ids';

  final String? tenantId;
  final int maxIds;
  final dynamic Function(String key) _read;
  final void Function(String key, dynamic value) _write;
  final void Function(String key) _remove;

  String get _key {
    final id = tenantId?.trim();
    if (id == null || id.isEmpty) return keyBase;
    return '${keyBase}_$id';
  }

  /// Most recent first.
  List<String> load() {
    final raw = _read(_key);
    if (raw is! List) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final e in raw) {
      final id = e?.toString().trim() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      out.add(id);
      if (out.length >= maxIds) break;
    }
    return out;
  }

  void record(String clientId) {
    final id = clientId.trim();
    if (id.isEmpty) return;
    final next = <String>[id, for (final x in load()) if (x != id) x];
    if (next.length > maxIds) {
      _write(_key, next.sublist(0, maxIds));
    } else {
      _write(_key, next);
    }
  }

  void clear() => _remove(_key);
}
