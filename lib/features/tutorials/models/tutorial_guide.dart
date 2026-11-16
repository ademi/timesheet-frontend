/// Screenshot (or illustration) embedded in a tutorial section.
class TutorialImage {
  const TutorialImage({
    required this.assetPath,
    this.caption,
  });

  /// Path under Flutter assets, e.g. `assets/tutorials/roster-publish/board.png`.
  final String assetPath;

  /// Optional caption shown under the image (ShiftCare-style).
  final String? caption;
}

/// One section inside a tutorial article (heading + prose + optional steps).
class TutorialSection {
  const TutorialSection({
    required this.id,
    required this.heading,
    this.body,
    this.steps = const [],
    this.images = const [],
  });

  final String id;
  final String heading;

  /// Explanatory copy for this section (article-style, not a step list).
  final String? body;

  /// Numbered how-to steps that belong under this section.
  final List<String> steps;

  /// Real-system screenshots for this section (0–N).
  final List<TutorialImage> images;
}

/// Curated in-app tutorial article for staff web.
///
/// Shown in the home list as an article; detail mixes prose sections with
/// embedded steps (ShiftCare help-style).
class TutorialGuide {
  const TutorialGuide({
    required this.id,
    required this.title,
    required this.summary,
    required this.sections,
    this.tags = const [],
    this.routeHints = const [],
    this.videoUrl,
    this.writtenBy,
    this.updatedLabel,
  });

  final String id;
  final String title;

  /// Short blurb for the list card and article intro.
  final String summary;

  final List<TutorialSection> sections;
  final List<String> tags;

  /// Path prefixes (e.g. `/staff/visits`) used to pin this guide when relevant.
  final List<String> routeHints;

  /// Optional Loom / YouTube / docs URL opened in a new tab.
  final String? videoUrl;

  /// Optional byline (e.g. "Rostiq team").
  final String? writtenBy;

  /// Optional date / freshness label (e.g. "November 2026").
  final String? updatedLabel;

  /// Total screenshot count across all sections.
  int get imageCount =>
      sections.fold(0, (sum, s) => sum + s.images.length);

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
    for (final section in sections) {
      if (section.heading.toLowerCase().contains(q)) return true;
      final body = section.body;
      if (body != null && body.toLowerCase().contains(q)) return true;
      for (final step in section.steps) {
        if (step.toLowerCase().contains(q)) return true;
      }
      for (final image in section.images) {
        final caption = image.caption;
        if (caption != null && caption.toLowerCase().contains(q)) return true;
      }
    }
    return false;
  }
}
