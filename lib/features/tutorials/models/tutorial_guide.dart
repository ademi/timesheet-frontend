/// Curated in-app tutorial guide for staff web.
class TutorialGuide {
  const TutorialGuide({
    required this.id,
    required this.title,
    required this.summary,
    required this.steps,
    this.tags = const [],
    this.routeHints = const [],
    this.videoUrl,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> steps;
  final List<String> tags;

  /// Path prefixes (e.g. `/staff/visits`) used to pin this guide when relevant.
  final List<String> routeHints;

  /// Optional Loom / YouTube / docs URL opened in a new tab.
  final String? videoUrl;

  bool matchesRoute(String path) {
    if (path.isEmpty || routeHints.isEmpty) return false;
    for (final hint in routeHints) {
      if (hint.isEmpty) continue;
      if (path == hint || path.startsWith('$hint/')) return true;
    }
    return false;
  }

  bool matchesQuery(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if (summary.toLowerCase().contains(q)) return true;
    for (final tag in tags) {
      if (tag.toLowerCase().contains(q)) return true;
    }
    for (final step in steps) {
      if (step.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}
