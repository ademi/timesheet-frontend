import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/attendance/controllers/attendance_review_controller.dart';
import 'package:rostiq/features/attendance/data/attendance_review_models.dart';
import 'package:rostiq/features/attendance/data/repositories/attendance_repository.dart';

class _MockAttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  late _MockAttendanceRepository repository;

  setUp(() {
    Get.testMode = true;
    repository = _MockAttendanceRepository();
  });

  tearDown(Get.reset);

  AttendanceExceptionOut sampleException({
    String id = 'ex-1',
    String visitId = 'visit-1',
    DateTime? openedAt,
  }) {
    return AttendanceExceptionOut(
      id: id,
      tenantId: 'tenant-1',
      visitId: visitId,
      timeEntryId: 'te-1',
      kind: 'location_missing',
      reasonCode: 'gps_unavailable',
      status: 'pending_ack',
      openedAt: openedAt ?? DateTime.utc(2026, 9, 17, 10),
    );
  }

  AttendanceSyncConflictOut sampleConflict({
    String id = 'sc-1',
    String visitId = 'visit-2',
    DateTime? createdAt,
    String status = 'open',
  }) {
    return AttendanceSyncConflictOut(
      id: id,
      tenantId: 'tenant-1',
      visitId: visitId,
      contractorId: 'contractor-1',
      clientEventId: 'ce-1',
      kind: 'check_in',
      failureDetail: 'visit_cancelled',
      payloadJson: const {},
      status: status,
      createdAt: createdAt ?? DateTime.utc(2026, 9, 17, 11),
    );
  }

  AttendanceReviewController buildController({String? visitIdFilter}) {
    return AttendanceReviewController(
      repository: repository,
      visitIdFilter: visitIdFilter,
      showSnack: (_, __) {},
    );
  }

  test('loads exceptions and conflicts into one sorted list', () async {
    when(
      () => repository.listExceptions(status: 'pending_ack'),
    ).thenAnswer((_) async => [sampleException()]);
    when(
      () => repository.listSyncConflicts(status: 'open'),
    ).thenAnswer((_) async => [sampleConflict()]);

    final controller = buildController();
    await controller.load();

    expect(controller.items.length, 2);
    expect(
      controller.items.map((e) => e.kind).toSet(),
      {AttendanceReviewKind.exception, AttendanceReviewKind.syncConflict},
    );
    // Newest first (conflict at 11:00 before exception at 10:00).
    expect(controller.items.first.kind, AttendanceReviewKind.syncConflict);
    expect(controller.items.last.kind, AttendanceReviewKind.exception);
  });

  test('approve exception calls ack API', () async {
    var exceptionCalls = 0;
    when(
      () => repository.listExceptions(status: 'pending_ack'),
    ).thenAnswer((_) async {
      exceptionCalls++;
      if (exceptionCalls == 1) return [sampleException()];
      return <AttendanceExceptionOut>[];
    });
    when(
      () => repository.listSyncConflicts(status: 'open'),
    ).thenAnswer((_) async => <AttendanceSyncConflictOut>[]);
    when(
      () => repository.ackException(
        'ex-1',
        decision: 'approved',
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async => sampleException(id: 'ex-1'));

    final controller = buildController();
    await controller.load();
    final item = controller.items.single;

    await controller.approveException(item, note: 'Looks fine');

    verify(
      () => repository.ackException(
        'ex-1',
        decision: 'approved',
        note: 'Looks fine',
      ),
    ).called(1);
  });

  test('force-accept conflict requires note length >= 8', () async {
    when(
      () => repository.listExceptions(status: 'pending_ack'),
    ).thenAnswer((_) async => <AttendanceExceptionOut>[]);
    when(
      () => repository.listSyncConflicts(status: 'open'),
    ).thenAnswer((_) async => [sampleConflict()]);

    final controller = buildController();
    await controller.load();
    final item = controller.items.single;

    final ok = await controller.forceAcceptConflict(item, note: 'short');

    expect(ok, isFalse);
    expect(controller.actionError.value, isNotNull);
    verifyNever(
      () => repository.forceAcceptSyncConflict(any(), note: any(named: 'note')),
    );
  });

  test('force-accept conflict calls API when note is long enough', () async {
    var conflictCalls = 0;
    when(
      () => repository.listExceptions(status: 'pending_ack'),
    ).thenAnswer((_) async => <AttendanceExceptionOut>[]);
    when(
      () => repository.listSyncConflicts(status: 'open'),
    ).thenAnswer((_) async {
      conflictCalls++;
      if (conflictCalls == 1) return [sampleConflict()];
      return <AttendanceSyncConflictOut>[];
    });
    when(
      () => repository.forceAcceptSyncConflict('sc-1', note: 'Verified OK'),
    ).thenAnswer(
      (_) async => sampleConflict(id: 'sc-1', status: 'force_accepted'),
    );

    final controller = buildController();
    await controller.load();
    final item = controller.items.single;

    final ok = await controller.forceAcceptConflict(item, note: 'Verified OK');

    expect(ok, isTrue);
    verify(
      () => repository.forceAcceptSyncConflict('sc-1', note: 'Verified OK'),
    ).called(1);
  });

  test('filter chips narrow to GPS or Sync kinds', () async {
    when(
      () => repository.listExceptions(status: 'pending_ack'),
    ).thenAnswer((_) async => [sampleException()]);
    when(
      () => repository.listSyncConflicts(status: 'open'),
    ).thenAnswer((_) async => [sampleConflict()]);

    final controller = buildController();
    await controller.load();

    controller.setFilter(AttendanceReviewFilter.gps);
    expect(controller.visibleItems.length, 1);
    expect(controller.visibleItems.single.kind, AttendanceReviewKind.exception);

    controller.setFilter(AttendanceReviewFilter.sync);
    expect(controller.visibleItems.length, 1);
    expect(
      controller.visibleItems.single.kind,
      AttendanceReviewKind.syncConflict,
    );

    controller.setFilter(AttendanceReviewFilter.all);
    expect(controller.visibleItems.length, 2);
  });

  test('variance filter keeps geofence / early / late exceptions only', () async {
    when(
      () => repository.listExceptions(status: 'pending_ack'),
    ).thenAnswer(
      (_) async => [
        sampleException(id: 'gps'),
        AttendanceExceptionOut(
          id: 'out',
          tenantId: 'tenant-1',
          visitId: 'visit-3',
          timeEntryId: 'te-2',
          kind: 'geofence_outside',
          reasonCode: 'geofence_outside',
          status: 'pending_ack',
          openedAt: DateTime.utc(2026, 9, 17, 12),
        ),
        AttendanceExceptionOut(
          id: 'early',
          tenantId: 'tenant-1',
          visitId: 'visit-4',
          timeEntryId: 'te-3',
          kind: 'early_clock_out',
          reasonCode: 'early_clock_out',
          status: 'pending_ack',
          openedAt: DateTime.utc(2026, 9, 17, 13),
        ),
      ],
    );
    when(
      () => repository.listSyncConflicts(status: 'open'),
    ).thenAnswer((_) async => [sampleConflict()]);

    final controller = buildController();
    await controller.load();
    controller.setFilter(AttendanceReviewFilter.variance);

    expect(controller.visibleItems.length, 2);
    expect(
      controller.visibleItems.map((i) => i.exception!.kind).toSet(),
      {'geofence_outside', 'early_clock_out'},
    );
    expect(
      controller.visibleItems
          .firstWhere((i) => i.exception!.kind == 'geofence_outside')
          .headline,
      'Clock-in outside geofence',
    );
    expect(
      controller.visibleItems
          .firstWhere((i) => i.exception!.kind == 'early_clock_out')
          .headline,
      'Early clock-out',
    );
  });
}
