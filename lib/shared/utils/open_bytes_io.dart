import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Native / test fallback: share sheet so the user can open the file externally.
Future<void> openBytesInViewer({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  return SharePlus.instance.share(
    ShareParams(
      title: filename,
      files: [XFile.fromData(bytes, mimeType: mimeType, name: filename)],
      fileNameOverrides: [filename],
    ),
  );
}
