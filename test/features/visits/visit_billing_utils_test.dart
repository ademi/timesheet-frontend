import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/utils/visit_billing_utils.dart';

final _start = DateTime.utc(2026, 8, 13, 9);
final _end = DateTime.utc(2026, 8, 13, 11);

VisitOut _visit({List<VisitTaskOut> tasks = const []}) {
  return VisitOut(
    id: 'visit-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    contractorId: 'contractor-1',
    scheduledStart: _start,
    scheduledEnd: _end,
    status: 'scheduled',
    source: 'manual',
    latitude: 0,
    longitude: 0,
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: _start,
    updatedAt: _start,
    tasks: tasks,
  );
}

VisitTaskOut _task({String? supportItemCode, int? billableMinutes}) {
  return VisitTaskOut(
    id: 'task-1',
    visitId: 'visit-1',
    title: 'Personal care',
    sortOrder: 0,
    isDone: false,
    supportItemCode: supportItemCode,
    billableMinutes: billableMinutes,
  );
}

void main() {
  test('visitScheduledDurationMinutes uses scheduled window', () {
    expect(visitScheduledDurationMinutes(_visit()), 120);
  });

  test('codedTaskBillableMinutesTotal sums coded tasks only', () {
    final visit = _visit(
      tasks: [
        _task(supportItemCode: '01_011_0107_1_1', billableMinutes: 60),
        _task(supportItemCode: null, billableMinutes: 30),
        VisitTaskOut(
          id: 'task-2',
          visitId: 'visit-1',
          title: 'Transport',
          sortOrder: 1,
          isDone: false,
          supportItemCode: '01_011_0107_1_1',
          billableMinutes: 45,
        ),
      ],
    );
    expect(codedTaskBillableMinutesTotal(visit), 105);
    expect(visitHasCodedTasks(visit), isTrue);
  });

  test('taskMinutesExceedVisitDuration detects over-allocation', () {
    final ok = _visit(
      tasks: [
        _task(supportItemCode: '01_011_0107_1_1', billableMinutes: 90),
      ],
    );
    final over = _visit(
      tasks: [
        _task(supportItemCode: '01_011_0107_1_1', billableMinutes: 90),
        VisitTaskOut(
          id: 'task-2',
          visitId: 'visit-1',
          title: 'Transport',
          sortOrder: 1,
          isDone: false,
          supportItemCode: '01_011_0107_1_1',
          billableMinutes: 45,
        ),
      ],
    );
    expect(taskMinutesExceedVisitDuration(ok), isFalse);
    expect(taskMinutesExceedVisitDuration(over), isTrue);
  });
}
