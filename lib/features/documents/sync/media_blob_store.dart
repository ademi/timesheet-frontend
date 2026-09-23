import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Persists media bytes for the upload outbox (survives process kill).
abstract class MediaBlobStore {
  Future<String> write({
    required String clientUploadId,
    required List<int> bytes,
    required String filename,
  });

  Future<Uint8List> read(String localPath);

  Future<void> delete(String localPath);
}

class PathMediaBlobStore implements MediaBlobStore {
  @override
  Future<String> write({
    required String clientUploadId,
    required List<int> bytes,
    required String filename,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/media_outbox');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '${dir.path}/${clientUploadId}_$safeName';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  @override
  Future<Uint8List> read(String localPath) => File(localPath).readAsBytes();

  @override
  Future<void> delete(String localPath) async {
    final f = File(localPath);
    if (await f.exists()) {
      await f.delete();
    }
  }
}

/// In-memory blob store for unit tests (process-kill restore tested via GetStorage metadata).
class MemoryMediaBlobStore implements MediaBlobStore {
  final Map<String, Uint8List> _bytes = {};

  @override
  Future<String> write({
    required String clientUploadId,
    required List<int> bytes,
    required String filename,
  }) async {
    final path = 'memory://$clientUploadId/$filename';
    _bytes[path] = Uint8List.fromList(bytes);
    return path;
  }

  @override
  Future<Uint8List> read(String localPath) async {
    final b = _bytes[localPath];
    if (b == null) {
      throw StateError('blob_missing:$localPath');
    }
    return b;
  }

  @override
  Future<void> delete(String localPath) async {
    _bytes.remove(localPath);
  }
}
