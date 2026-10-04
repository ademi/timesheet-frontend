import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/contractor_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';
import 'package:rostiq/features/visits/services/visit_location_service.dart';
import 'package:rostiq/features/visits/sync/outbox_models.dart';
import 'package:rostiq/features/visits/sync/outbox_store.dart';
import 'package:rostiq/features/visits/sync/sync_worker.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeLocation extends VisitLocationService {
  _FakeLocation(this.attempt);

  final GpsAttempt attempt;

  @override
  bool get isWeb => false;

  @override
  Future<GpsAttempt> tryGps({
    Duration timeout = const Duration(seconds: 8),
  }) async =>
      attempt;
}

VisitOut _visit({String status = 'scheduled', DateTime? scheduledStart}) {
  final t = scheduledStart ?? DateTime.now().toUtc().add(const Duration(hours: 1));
  return VisitOut(
    id: 'visit-1',
    tenantId: 't',
    jobId: 'j',
    contractorId: 'c',
    scheduledStart: t,
    scheduledEnd: t.add(const Duration(hours: 2)),
    status: status,
    source: 'claim',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  late GetStorage box;
  late OutboxStore store;
  late Directory storageDirectory;
  late _MockVisitsRepository visits;
  late _MockSessionService session;
  late SyncWorker worker;
  late ContractorVisitsController controller;

  const eventId = '11111111-1111-1111-1111-111111111111';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory =
        await Directory.systemTemp.createTemp('rostiq_checkin_outbox_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return storageDirectory.path;
      }
      return null;
    });
    registerFallbackValue(const VisitGpsBody(lat: 0, lng: 0));
    registerFallbackValue(<String, dynamic>{});
  });

  tearDownAll(() async {
    try {
      await storageDirectory.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    Get.testMode = true;
    await GetStorage.init('checkin_outbox_test');
    box = GetStorage('checkin_outbox_test');
    await box.erase();
    store = OutboxStore(box);
    visits = _MockVisitsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(false);
    when(
      () => session.hasPermission(AppPermissions.visitsCheckIn),
    ).thenReturn(true);
    when(
      () => session.hasPermission(AppPermissions.visitsComplete),
    ).thenReturn(true);
    when(
      () => session.hasPermission(AppPermissions.visitsRead),
    ).thenReturn(true);
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => []);

    worker = SyncWorker(
      store: store,
      repository: visits,
      connectivityStream: const Stream.empty(),
      observeLifecycle: false,
      backoffForAttempt: (_) => Duration.zero,
      onChanged: () {},
    );

    controller = ContractorVisitsController(
      repository: visits,
      shiftsRepository: _MockShiftsRepository(),
      session: session,
      location: _FakeLocation(
        const GpsAttempt.failed('unavailable', 'airplane'),
      ),
      outbox: store,
      syncWorker: worker,
      isDeviceOffline: () async => true,
      newEventId: () => eventId,
    );
    controller.onInit();
    controller.selected.value = _visit();
  });

  tearDown(() {
    controller.onClose();
    Get.reset();
  });

  test('checkIn enqueues outbox and does not toast success without ack',
      () async {
    when(
      () => visits.checkIn(
        id: any(named: 'id'),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(
      const AppFailure(
        code: 'network_error',
        message: 'Could not reach the API.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    await controller.checkIn();

    expect(store.pending(), hasLength(1));
    expect(store.pending().single.clientEventId, eventId);
    expect(controller.selectedSyncUi, VisitClockSyncUi.pending);
    expect(controller.selected.value?.status, 'checked_in');
    expect(controller.errorMessage.value, isNull);
    verifyNever(() => visits.getVisit(any()));
  });

  test('syncWorker ack removes outbox and sets synced', () async {
    await store.append(
      ClockOutboxItem(
        clientEventId: eventId,
        visitId: 'visit-1',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'airplane',
        deviceOffline: true,
      ),
    );
    controller.selected.value = _visit(status: 'checked_in');
    controller.outboxRevision.value++;

    when(
      () => visits.checkIn(
        id: any(named: 'id'),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => const VisitCheckInOut(
        visitId: 'visit-1',
        status: 'checked_in',
        timeEntryId: 'te-1',
      ),
    );
    when(() => visits.getVisit('visit-1')).thenAnswer(
      (_) async => _visit(status: 'checked_in'),
    );

    var acked = false;
    final flushWorker = SyncWorker(
      store: store,
      repository: visits,
      connectivityStream: const Stream.empty(),
      observeLifecycle: false,
      backoffForAttempt: (_) => Duration.zero,
      onAcked: (item) {
        acked = true;
        controller.onOutboxAcked(item);
      },
    );

    await flushWorker.flush();

    expect(store.pending(), isEmpty);
    expect(acked, isTrue);
    expect(controller.selected.value?.status, 'checked_in');
    expect(controller.selectedSyncUi, VisitClockSyncUi.none);
  });

  test('retryable markAttempt lastError stays Pending sync UI', () async {
    await store.append(
      ClockOutboxItem(
        clientEventId: eventId,
        visitId: 'visit-1',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'airplane',
        deviceOffline: true,
        attempts: 1,
        lastError: 'offline',
      ),
    );
    controller.outboxRevision.value++;
    expect(controller.selectedSyncUi, VisitClockSyncUi.pending);
  });

  test('conflicted outbox maps to SyncFailed UI', () async {
    await store.append(
      ClockOutboxItem(
        clientEventId: eventId,
        visitId: 'visit-1',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'airplane',
        deviceOffline: true,
        isConflict: true,
        lastError: 'invalid_visit_status',
      ),
    );
    controller.outboxRevision.value++;
    expect(controller.selectedSyncUi, VisitClockSyncUi.failed);
    expect(controller.selectedHasConflict, isTrue);
  });

  test('dismissConflictForSelected clears conflicted item', () async {
    await store.append(
      ClockOutboxItem(
        clientEventId: eventId,
        visitId: 'visit-1',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'airplane',
        deviceOffline: true,
        isConflict: true,
        lastError: 'invalid_visit_status',
      ),
    );
    controller.outboxRevision.value++;
    await controller.dismissConflictForSelected();
    expect(store.pending(), isEmpty);
    expect(controller.selectedSyncUi, VisitClockSyncUi.none);
  });

  test('terminal conflict reverts optimistic checked_in', () async {
    when(
      () => visits.checkIn(
        id: any(named: 'id'),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(
      const AppFailure(
        code: 'invalid_visit_status',
        message: 'Cannot change this visit in its current status.',
        presentation: AppFailurePresentation.toast,
        statusCode: 409,
      ),
    );
    when(
      () => visits.reportSyncConflict(
        visitId: any(named: 'visitId'),
        clientEventId: any(named: 'clientEventId'),
        kind: any(named: 'kind'),
        failureDetail: any(named: 'failureDetail'),
        payloadJson: any(named: 'payloadJson'),
      ),
    ).thenAnswer((_) async {});

    await controller.checkIn();

    expect(store.pending().single.isConflict, isTrue);
    expect(controller.selected.value?.status, 'scheduled');
    expect(controller.selectedSyncUi, VisitClockSyncUi.failed);
  });

  test('refresh dismisses conflict when server already advanced', () async {
    await store.append(
      ClockOutboxItem(
        clientEventId: eventId,
        visitId: 'visit-1',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'airplane',
        deviceOffline: true,
        isConflict: true,
        lastError: 'invalid_visit_status',
      ),
    );
    controller.outboxRevision.value++;
    when(() => visits.getVisit('visit-1')).thenAnswer(
      (_) async => _visit(status: 'checked_in'),
    );

    await controller.refreshSelected();

    expect(store.pending(), isEmpty);
    expect(controller.selected.value?.status, 'checked_in');
    expect(controller.selectedSyncUi, VisitClockSyncUi.none);
  });

  test('late checkIn stores late_reason_code on outbox item', () async {
    when(
      () => visits.checkIn(
        id: any(named: 'id'),
        body: any(named: 'body'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(
      const AppFailure(
        code: 'network_error',
        message: 'Could not reach the API.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    controller = ContractorVisitsController(
      repository: visits,
      shiftsRepository: _MockShiftsRepository(),
      session: session,
      location: _FakeLocation(
        const GpsAttempt.failed('unavailable', 'airplane'),
      ),
      outbox: store,
      syncWorker: worker,
      isDeviceOffline: () async => true,
      newEventId: () => eventId,
      promptLateReason: () async => 'traffic',
    );
    controller.onInit();
    controller.selected.value = _visit(
      scheduledStart: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
    );

    await controller.checkIn();

    expect(store.pending(), hasLength(1));
    expect(store.pending().single.lateReasonCode, 'traffic');
    final body = gpsBodyFromOutbox(store.pending().single);
    expect(body.toJson()['late_reason_code'], 'traffic');
  });
}
