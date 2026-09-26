import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rostiq/features/documents/sync/media_outbox_models.dart';
import 'package:rostiq/features/documents/sync/media_outbox_store.dart';

void main() {
  late GetStorage box;
  late MediaOutboxStore store;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp('media_outbox_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return storageDirectory.path;
      }
      return null;
    });
  });

  tearDownAll(() async {
    try {
      await storageDirectory.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await GetStorage.init('media_outbox_test');
    box = GetStorage('media_outbox_test');
    await box.erase();
    store = MediaOutboxStore(box);
  });

  MediaOutboxItem _item(String id) => MediaOutboxItem(
        clientUploadId: id,
        ownerType: 'visit',
        ownerId: 'v1',
        filename: 'photo.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 3,
        localPath: 'memory://$id/photo.jpg',
        createdAtIso: DateTime.utc(2026, 9, 23, 8).toIso8601String(),
        visitId: 'v1',
        fieldId: 'f1',
      );

  test('append then pending; ack removes; GetStorage restore', () async {
    await store.append(_item('u1'));
    expect(store.pending(), hasLength(1));

    // Process-kill restore: new store instance same box.
    final restored = MediaOutboxStore(box);
    expect(restored.pending().single.clientUploadId, 'u1');

    await store.ack('u1');
    expect(store.pending(), isEmpty);
    expect(MediaOutboxStore(box).pending(), isEmpty);
  });

  test('clearDestructive blocked without confirm', () async {
    await store.append(_item('u2'));
    expect(
      () => store.clearDestructive(confirmDiscard: false),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'media_outbox_not_empty',
        ),
      ),
    );
  });

  test('markAttempt then markTerminalFailure', () async {
    await store.append(_item('u3'));
    await store.markAttempt('u3', 'network');
    expect(store.pending().single.attempts, 1);
    expect(store.pending().single.stage, MediaOutboxStage.failed);
    await store.markTerminalFailure('u3', 'scan_blocked');
    expect(store.pending().single.isTerminalFailure, isTrue);
  });

  test('markAttempt preserves documentId for poll resume (C3)', () async {
    await store.append(_item('u4').copyWith(documentId: 'doc-keep'));
    await store.markAttempt('u4', 'poll timeout');
    expect(store.pending().single.documentId, 'doc-keep');
    expect(store.pending().single.stage, MediaOutboxStage.failed);
  });
}
