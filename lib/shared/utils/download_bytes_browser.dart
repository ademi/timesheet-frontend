import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

/// Browser file download (JS and Wasm Flutter web).
Future<bool> downloadBytesAsFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final blob = Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    BlobPropertyBag(type: mimeType),
  );
  final url = URL.createObjectURL(blob);
  final anchor = document.createElement('a') as HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.style.display = 'none';
  document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  unawaited(
    Future<void>.delayed(const Duration(seconds: 30), () {
      URL.revokeObjectURL(url);
    }),
  );
  return true;
}
