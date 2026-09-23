import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/features/documents/sync/media_blob_store.dart';
import 'package:rostiq/features/documents/sync/media_outbox_models.dart';
import 'package:rostiq/features/documents/sync/media_outbox_store.dart';
import 'package:rostiq/features/documents/sync/media_sync_worker.dart';

class _MockPipeline extends Mock implements DocumentPipeline {}

void main() {
  late GetStorage box;
  late MediaOutboxStore store;
  late MemoryMediaBlobStore blobs;
  late _MockPipeline pipeline;
  late StreamController<List<ConnectivityResult>> connectivity;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp('media_sync_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return storageDirectory.path;
      }
      return null;
    });
    registerFallbackValue(
      const UploadUrlRequest(
        ownerType: 'visit',
        ownerId: 'v1',
        filename: 'a.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1,
      ),
    );
  });

  tearDownAll(() async {
    try {
      await storageDirectory.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await GetStorage.init('media_sync_test');
    box = GetStorage('media_sync_test');
    await box.erase();
    store = MediaOutboxStore(box);
    blobs = MemoryMediaBlobStore();
    pipeline = _MockPipeline();
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();
  });

  tearDown(() async {
    await connectivity.close();
  });

  Future<MediaOutboxItem> enqueue() async {
    const id = 'upload-1';
    final path = await blobs.write(
      clientUploadId: id,
      bytes: [1, 2, 3],
      filename: 'shot.jpg',
    );
    final item = MediaOutboxItem(
      clientUploadId: id,
      ownerType: 'visit',
      ownerId: 'v1',
      filename: 'shot.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 3,
      localPath: path,
      createdAtIso: DateTime.utc(2026, 9, 23).toIso8601String(),
      visitId: 'v1',
      fieldId: 'photo',
    );
    await store.append(item);
    return item;
  }

  test('enqueue → fail → retry → ACK', () async {
    await enqueue();
    var calls = 0;
    when(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
        onSendProgress: any(named: 'onSendProgress'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw const AppFailure(
          code: 'network',
          message: 'offline',
          statusCode: 503,
          presentation: AppFailurePresentation.toast,
        );
      }
      return const DocumentOut(
        id: 'doc-9',
        ownerType: 'visit',
        ownerId: 'v1',
        filename: 'shot.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 3,
        scanStatus: 'clean',
      );
    });
    when(
      () => pipeline.pollScanStatus(
        documentId: any(named: 'documentId'),
        ownerType: any(named: 'ownerType'),
        ownerId: any(named: 'ownerId'),
      ),
    ).thenAnswer(
      (_) async => const DocumentOut(
        id: 'doc-9',
        ownerType: 'visit',
        ownerId: 'v1',
        filename: 'shot.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 3,
        scanStatus: 'clean',
      ),
    );

    MediaOutboxItem? acked;
    final worker = MediaSyncWorker(
      store: store,
      blobs: blobs,
      pipeline: pipeline,
      connectivityStream: connectivity.stream,
      observeLifecycle: false,
      backoffForAttempt: (_) => Duration.zero,
      onAcked: (item) => acked = item,
    );
    // Do not start() — that schedules an eager flush and races the fail→retry assert.

    await worker.flush();
    expect(store.pending(), hasLength(1));
    expect(store.pending().single.attempts, greaterThan(0));

    await worker.flush();
    expect(store.pending(), isEmpty);
    expect(acked?.documentId, 'doc-9');
    worker.dispose();
  });
}
