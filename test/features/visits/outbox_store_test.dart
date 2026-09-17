import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rostiq/features/visits/sync/outbox_models.dart';
import 'package:rostiq/features/visits/sync/outbox_store.dart';

void main() {
  late GetStorage box;
  late OutboxStore store;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp('rostiq_outbox_');
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
    await GetStorage.init('outbox_test');
    box = GetStorage('outbox_test');
    await box.erase();
    store = OutboxStore(box);
  });

  test('append then pending lists item; ack removes it', () async {
    final item = ClockOutboxItem(
      clientEventId: 'e1',
      visitId: 'v1',
      kind: ClockOutboxKind.checkIn,
      tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
      locationStatus: 'unavailable',
      locationFailReason: 'airplane',
      deviceOffline: true,
    );
    await store.append(item);
    expect(store.pending(), hasLength(1));
    await store.ack('e1');
    expect(store.pending(), isEmpty);
  });

  test('pendingCount blocks destructive clear', () async {
    await store.append(ClockOutboxItem(
      clientEventId: 'e2',
      visitId: 'v1',
      kind: ClockOutboxKind.checkIn,
      tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
      locationStatus: 'unavailable',
      locationFailReason: 'x',
      deviceOffline: true,
    ));
    expect(
      () => store.clearDestructive(confirmDiscard: false),
      throwsA(isA<StateError>()),
    );
  });

  test('markConflict sets lastError and isConflict', () async {
    await store.append(ClockOutboxItem(
      clientEventId: 'e3',
      visitId: 'v1',
      kind: ClockOutboxKind.checkIn,
      tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
      locationStatus: 'unavailable',
      locationFailReason: 'x',
      deviceOffline: true,
    ));
    await store.markConflict('e3', 'invalid_visit_status');
    final item = store.pending().single;
    expect(item.isConflict, isTrue);
    expect(item.lastError, 'invalid_visit_status');
    expect(item.attempts, 1);
  });
}
