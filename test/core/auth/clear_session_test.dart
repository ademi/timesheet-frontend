import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/auth/clear_session.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/services/token_storage.dart';
import 'package:rostiq/features/visits/sync/outbox_models.dart';
import 'package:rostiq/features/visits/sync/outbox_store.dart';

class _MockSessionService extends Mock implements SessionService {}

class _MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late GetStorage box;
  late OutboxStore store;
  late _MockSessionService session;
  late _MockTokenStorage tokenStorage;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp('rostiq_clear_session_');
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
    await storageDirectory.delete(recursive: true);
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    await GetStorage.init('clear_session_test');
    box = GetStorage('clear_session_test');
    await box.erase();
    store = OutboxStore(box);
    session = _MockSessionService();
    tokenStorage = _MockTokenStorage();
    when(() => session.clear()).thenAnswer((_) async {});
    when(() => tokenStorage.clear()).thenAnswer((_) async {});
  });

  tearDown(Get.reset);

  test('clearSession throws when outbox pending without confirm', () async {
    await store.append(
      ClockOutboxItem(
        clientEventId: 'e1',
        visitId: 'v1',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'offline',
        deviceOffline: true,
      ),
    );

    await expectLater(
      clearSession(
        confirmDiscardOutbox: false,
        sessionService: session,
        tokenStorage: tokenStorage,
        outboxStore: store,
      ),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'outbox_not_empty')),
    );
    verifyNever(() => session.clear());
    verifyNever(() => tokenStorage.clear());
    expect(store.pending(), hasLength(1));
  });

  test('clearSession discards outbox and clears session when confirmed', () async {
    await store.append(
      ClockOutboxItem(
        clientEventId: 'e2',
        visitId: 'v1',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'offline',
        deviceOffline: true,
      ),
    );

    await clearSession(
      confirmDiscardOutbox: true,
      sessionService: session,
      tokenStorage: tokenStorage,
      outboxStore: store,
    );

    verify(() => session.clear()).called(1);
    verify(() => tokenStorage.clear()).called(1);
    expect(store.pending(), isEmpty);
  });

  test('clearSession clears session when outbox is empty', () async {
    await clearSession(
      sessionService: session,
      tokenStorage: tokenStorage,
      outboxStore: store,
    );

    verify(() => session.clear()).called(1);
    verify(() => tokenStorage.clear()).called(1);
  });
}
