import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Native / test fallback: open the system share sheet with the file bytes.
Future<bool> downloadBytesAsFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: filename)],
      fileNameOverrides: [filename],
    ),
  );
  return true;
}
