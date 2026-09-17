import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';
import 'package:rostiq/features/visits/sync/outbox_models.dart';
import 'package:rostiq/features/visits/sync/outbox_store.dart';
import 'package:rostiq/features/visits/sync/sync_worker.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

ClockOutboxItem _item({
  required String id,
  required String visitId,
  required ClockOutboxKind kind,
  required String tap,
  int attempts = 0,
}) {
  return ClockOutboxItem(
    clientEventId: id,
    visitId: visitId,
    kind: kind,
    tapTimeIso: tap,
    locationStatus: 'unavailable',
    locationFailReason: 'x',
    deviceOffline: true,
    attempts: attempts,
  );
}

void main() {
  group('orderedForFlush', () {
    test('defers complete while check-in pending for same visit', () {
      final pending = [
        _item(
          id: 'c1',
          visitId: 'v1',
          kind: ClockOutboxKind.complete,
          tap: '2026-09-07T09:00:00.000Z',
        ),
        _item(
          id: 'i1',
          visitId: 'v1',
          kind: ClockOutboxKind.checkIn,
          tap: '2026-09-07T08:00:00.000Z',
        ),
        _item(
          id: 'i2',
          visitId: 'v2',
          kind: ClockOutboxKind.checkIn,
          tap: '2026-09-07T08:30:00.000Z',
        ),
      ];
      final ordered = orderedForFlush(pending);
      expect(ordered.map((e) => e.clientEventId).toList(), ['i1', 'i2']);
    });

    test('allows complete when no check-in pending for visit', () {
      final pending = [
        _item(
          id: 'c1',
          visitId: 'v1',
          kind: ClockOutboxKind.complete,
          tap: '2026-09-07T09:00:00.000Z',
        ),
      ];
      expect(orderedForFlush(pending).single.clientEventId, 'c1');
    });
  });

  group('SyncWorker flush', () {
    late Directory storageDirectory;
    late GetStorage box;
    late OutboxStore store;
    late _MockVisitsRepository visits;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      storageDirectory =
          await Directory.systemTemp.createTemp('rostiq_sync_worker_');
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
      await storageDirectory.delete(recursive: true);
    });

    setUp(() async {
      await GetStorage.init('sync_worker_test');
      box = GetStorage('sync_worker_test');
      await box.erase();
      store = OutboxStore(box);
      visits = _MockVisitsRepository();
    });

    test('overlapping flush coalesces into follow-up pass', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var checkInCalls = 0;

      when(
        () => visits.checkIn(
          id: any(named: 'id'),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {
        checkInCalls++;
        if (checkInCalls == 1) {
          started.complete();
          await release.future;
        }
        return VisitCheckInOut(
          visitId: 'v$checkInCalls',
          status: 'checked_in',
          timeEntryId: 'te-$checkInCalls',
        );
      });

      await store.append(
        _item(
          id: 'e1',
          visitId: 'v1',
          kind: ClockOutboxKind.checkIn,
          tap: '2026-09-07T08:00:00.000Z',
        ),
      );

      final worker = SyncWorker(
        store: store,
        repository: visits,
        connectivityStream: const Stream.empty(),
        observeLifecycle: false,
        backoffForAttempt: (_) => Duration.zero,
      );

      final first = worker.flush();
      await started.future;

      await store.append(
        _item(
          id: 'e2',
          visitId: 'v2',
          kind: ClockOutboxKind.checkIn,
          tap: '2026-09-07T08:01:00.000Z',
        ),
      );
      // Overlapping call while first still in flight.
      final second = worker.flush();
      release.complete();
      await Future.wait([first, second]);

      expect(checkInCalls, 2);
      expect(store.pending(), isEmpty);
    });

    test('online connectivity transition triggers flush', () async {
      final connectivity = StreamController<List<ConnectivityResult>>();
      addTearDown(connectivity.close);

      when(
        () => visits.checkIn(
          id: any(named: 'id'),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const VisitCheckInOut(
          visitId: 'v1',
          status: 'checked_in',
          timeEntryId: 'te-1',
        ),
      );

      await store.append(
        _item(
          id: 'e1',
          visitId: 'v1',
          kind: ClockOutboxKind.checkIn,
          tap: '2026-09-07T08:00:00.000Z',
        ),
      );

      final worker = SyncWorker(
        store: store,
        repository: visits,
        connectivityStream: connectivity.stream,
        observeLifecycle: false,
        backoffForAttempt: (_) => Duration.zero,
      );
      worker.start();
      addTearDown(worker.dispose);

      connectivity.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      expect(store.pending(), hasLength(1));

      connectivity.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.pending(), isEmpty);
    });

    test('markAttempt on network failure leaves item pending', () async {
      when(
        () => visits.checkIn(
          id: any(named: 'id'),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const AppFailure(
          code: 'network_error',
          message: 'offline',
          presentation: AppFailurePresentation.inline,
        ),
      );

      await store.append(
        _item(
          id: 'e1',
          visitId: 'v1',
          kind: ClockOutboxKind.checkIn,
          tap: '2026-09-07T08:00:00.000Z',
        ),
      );

      final worker = SyncWorker(
        store: store,
        repository: visits,
        connectivityStream: const Stream.empty(),
        observeLifecycle: false,
        backoffForAttempt: (_) => Duration.zero,
      );
      await worker.flush();

      expect(store.pending(), hasLength(1));
      expect(store.pending().single.attempts, 1);
      expect(store.pending().single.lastError, 'offline');
      expect(store.pending().single.isConflict, isFalse);
      verifyNever(
        () => visits.reportSyncConflict(
          visitId: any(named: 'visitId'),
          clientEventId: any(named: 'clientEventId'),
          kind: any(named: 'kind'),
          failureDetail: any(named: 'failureDetail'),
          payloadJson: any(named: 'payloadJson'),
        ),
      );
    });

    test('terminal failure reports sync conflict and marks outbox', () async {
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

      await store.append(
        _item(
          id: 'e1',
          visitId: 'v1',
          kind: ClockOutboxKind.checkIn,
          tap: '2026-09-07T08:00:00.000Z',
        ),
      );

      final worker = SyncWorker(
        store: store,
        repository: visits,
        connectivityStream: const Stream.empty(),
        observeLifecycle: false,
        backoffForAttempt: (_) => Duration.zero,
      );
      await worker.flush();

      expect(store.pending(), hasLength(1));
      expect(store.pending().single.isConflict, isTrue);
      expect(store.pending().single.lastError, 'invalid_visit_status');
      verify(
        () => visits.reportSyncConflict(
          visitId: 'v1',
          clientEventId: 'e1',
          kind: 'check_in',
          failureDetail: 'invalid_visit_status',
          payloadJson: any(named: 'payloadJson'),
        ),
      ).called(1);
      verify(
        () => visits.checkIn(
          id: any(named: 'id'),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);

      // Second flush must not re-POST check-in or conflict.
      clearInteractions(visits);
      await worker.flush();
      verifyNever(
        () => visits.checkIn(
          id: any(named: 'id'),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
      verifyNever(
        () => visits.reportSyncConflict(
          visitId: any(named: 'visitId'),
          clientEventId: any(named: 'clientEventId'),
          kind: any(named: 'kind'),
          failureDetail: any(named: 'failureDetail'),
          payloadJson: any(named: 'payloadJson'),
        ),
      );
    });

    test('flush calls checkIn before complete for same visit', () async {
      final order = <String>[];
      when(
        () => visits.checkIn(
          id: any(named: 'id'),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        order.add('checkIn:${invocation.namedArguments[#idempotencyKey]}');
        return const VisitCheckInOut(
          visitId: 'v1',
          status: 'checked_in',
          timeEntryId: 'te-1',
        );
      });
      when(
        () => visits.complete(
          id: any(named: 'id'),
          body: any(named: 'body'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        order.add('complete:${invocation.namedArguments[#idempotencyKey]}');
        return const VisitCompleteOut(
          visitId: 'v1',
          status: 'completed',
        );
      });

      // Enqueue complete first (earlier tap would be wrong); check-in earlier tap.
      await store.append(
        _item(
          id: 'c1',
          visitId: 'v1',
          kind: ClockOutboxKind.complete,
          tap: '2026-09-07T09:00:00.000Z',
        ),
      );
      await store.append(
        _item(
          id: 'i1',
          visitId: 'v1',
          kind: ClockOutboxKind.checkIn,
          tap: '2026-09-07T08:00:00.000Z',
        ),
      );

      final worker = SyncWorker(
        store: store,
        repository: visits,
        connectivityStream: const Stream.empty(),
        observeLifecycle: false,
        backoffForAttempt: (_) => Duration.zero,
      );
      await worker.flush();

      expect(order, ['checkIn:i1', 'complete:c1']);
      expect(store.pending(), isEmpty);
    });
  });
}
