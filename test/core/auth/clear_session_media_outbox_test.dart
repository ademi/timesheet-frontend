import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/auth/clear_session.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/services/token_storage.dart';
import 'package:rostiq/features/documents/sync/media_outbox_models.dart';
import 'package:rostiq/features/documents/sync/media_outbox_store.dart';

class _MockSessionService extends Mock implements SessionService {}

class _MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late GetStorage box;
  late MediaOutboxStore store;
  late _MockSessionService session;
  late _MockTokenStorage tokenStorage;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp('clear_media_');
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
    Get.testMode = true;
    Get.reset();
    await GetStorage.init('clear_session_media_test');
    box = GetStorage('clear_session_media_test');
    await box.erase();
    store = MediaOutboxStore(box);
    session = _MockSessionService();
    tokenStorage = _MockTokenStorage();
    when(() => session.clear()).thenAnswer((_) async {});
    when(() => tokenStorage.clear()).thenAnswer((_) async {});
  });

  tearDown(Get.reset);

  test('clearSession throws when media outbox pending without confirm', () async {
    await store.append(
      MediaOutboxItem(
        clientUploadId: 'm1',
        ownerType: 'visit',
        ownerId: 'v1',
        filename: 'a.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1,
        localPath: 'memory://m1',
        createdAtIso: DateTime.utc(2026, 9, 23).toIso8601String(),
      ),
    );

    await expectLater(
      clearSession(
        confirmDiscardOutbox: false,
        sessionService: session,
        tokenStorage: tokenStorage,
        mediaOutboxStore: store,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'media_outbox_not_empty',
        ),
      ),
    );
    verifyNever(() => session.clear());
  });

  test('clearSession discards media when confirmed', () async {
    await store.append(
      MediaOutboxItem(
        clientUploadId: 'm2',
        ownerType: 'visit',
        ownerId: 'v1',
        filename: 'a.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1,
        localPath: 'memory://m2',
        createdAtIso: DateTime.utc(2026, 9, 23).toIso8601String(),
      ),
    );

    await clearSession(
      confirmDiscardOutbox: true,
      sessionService: session,
      tokenStorage: tokenStorage,
      mediaOutboxStore: store,
    );
    expect(store.pending(), isEmpty);
    verify(() => session.clear()).called(1);
  });
}
