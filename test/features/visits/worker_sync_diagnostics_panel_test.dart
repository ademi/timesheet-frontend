import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rostiq/features/documents/sync/media_outbox_store.dart';
import 'package:rostiq/features/visits/services/visit_location_service.dart';
import 'package:rostiq/features/visits/sync/outbox_models.dart';
import 'package:rostiq/features/visits/sync/outbox_store.dart';
import 'package:rostiq/features/visits/widgets/worker_sync_diagnostics_panel.dart';

class _FakeLocation extends VisitLocationService {
  @override
  bool get isWeb => true;
}

void main() {
  late GetStorage box;
  late OutboxStore store;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp('diag_');
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
    await GetStorage.init('diag_test');
    box = GetStorage('diag_test');
    await box.erase();
    store = OutboxStore(box);
  });

  tearDown(Get.reset);

  testWidgets('shows pending clock sync count from OutboxStore', (tester) async {
    await store.append(
      ClockOutboxItem(
        clientEventId: 'e1',
        visitId: 'v1',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 23).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'offline',
        deviceOffline: true,
      ),
    );
    await store.append(
      ClockOutboxItem(
        clientEventId: 'e2',
        visitId: 'v2',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 23, 1).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'offline',
        deviceOffline: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkerSyncDiagnosticsPanel(
            location: _FakeLocation(),
            outboxStore: store,
            mediaOutboxStore: MediaOutboxStore(box),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending clock sync'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Pending media upload'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });
}
