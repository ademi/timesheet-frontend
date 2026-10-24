/// Public roadmap flags from `GET /v1/public/feature-flags`.
class PublicFeatureFlags {
  const PublicFeatureFlags({required this.flags});

  final Map<String, bool> flags;

  bool enabled(String key) => flags[key] == true;

  bool get comingNextProda => enabled('coming_next_proda');
  bool get comingNextBulkImport => enabled('coming_next_bulk_import');
  bool get comingNextDndRoster => enabled('coming_next_dnd_roster');

  factory PublicFeatureFlags.fromJson(Map<String, dynamic> json) {
    final raw = json['flags'];
    final map = <String, bool>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final v = e.value;
        if (v is bool) {
          map[e.key.toString()] = v;
        }
      }
    }
    return PublicFeatureFlags(flags: map);
  }

  static const empty = PublicFeatureFlags(flags: {});
}
