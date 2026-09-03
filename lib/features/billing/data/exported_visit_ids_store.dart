/// Session-scoped visit IDs known to be in a finalized export.
/// Survives list/detail route churn; clear on logout / tenant switch.
class ExportedVisitIdsStore {
  final Set<String> _ids = <String>{};

  Set<String> get ids => Set.unmodifiable(_ids);

  bool contains(String visitId) => _ids.contains(visitId);

  void mark(Iterable<String> visitIds) {
    for (final id in visitIds) {
      if (id.isEmpty) continue;
      _ids.add(id);
    }
  }

  void release(Iterable<String> visitIds) {
    for (final id in visitIds) {
      _ids.remove(id);
    }
  }

  void clear() => _ids.clear();
}
