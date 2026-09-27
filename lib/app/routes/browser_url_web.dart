import 'dart:html' as html;

/// Replaces the browser location without a GetX stack push (refresh-safe step sync).
void replaceBrowserUrl(String path, Map<String, String> query) {
  final uri = Uri(
    path: path,
    queryParameters: query.isEmpty ? null : query,
  );
  html.window.history.replaceState(null, '', uri.toString());
}
