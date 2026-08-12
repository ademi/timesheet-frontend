import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/utils/client_visit_windows.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';

VisitOut _v({
  required String id,
  required DateTime start,
  required String status,
}) {
  final end = start.add(const Duration(hours: 1));
  return VisitOut(
    id: id,
    tenantId: 't',
    jobId: 'j',
    contractorId: 'c',
    scheduledStart: start,
    scheduledEnd: end,
    status: status,
    source: 'manual',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: start,
    updatedAt: start,
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 12, 12);

  test('partitionClientVisits splits upcoming vs past and drops cancelled', () {
    final upcoming = _v(
      id: 'u',
      start: now.add(const Duration(days: 2)),
      status: 'scheduled',
    );
    final checkedIn = _v(
      id: 'ci',
      start: now.subtract(const Duration(hours: 1)),
      status: 'checked_in',
    );
    final past = _v(
      id: 'p',
      start: now.subtract(const Duration(days: 3)),
      status: 'completed',
    );
    final cancelled = _v(
      id: 'x',
      start: now.add(const Duration(days: 1)),
      status: 'cancelled',
    );

    final parts = partitionClientVisits(
      [upcoming, checkedIn, past, cancelled],
      now: now,
    );
    expect(parts.upcoming.map((e) => e.id), ['ci', 'u']); // start asc
    expect(parts.past.map((e) => e.id), ['p']); // start desc preferred
    expect(parts.past.every((e) => e.id != 'x'), isTrue);
  });
}
