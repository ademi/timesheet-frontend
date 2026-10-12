import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'download_bytes_browser.dart'
    if (dart.library.io) 'download_bytes_browser_stub.dart' as browser;
import 'download_bytes_io.dart' as native;

Future<bool> downloadBytesAsFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  if (kIsWeb) {
    return browser.downloadBytesAsFile(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }
  return native.downloadBytesAsFile(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );
}
