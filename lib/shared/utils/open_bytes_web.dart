import 'dart:html' as html;
import 'dart:typed_data';

/// Open bytes in a new browser tab for inline viewing (no download attribute).
Future<void> openBytesInViewer({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  // Revoke after the new tab has had time to load the blob.
  Future<void>.delayed(const Duration(seconds: 60), () {
    html.Url.revokeObjectUrl(url);
  });
}
