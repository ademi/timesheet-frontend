import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/utils/prior_client_workers.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/shared/utils/name_sort.dart';

VisitOut _visit({
  required String contractorId,
  String status = 'completed',
  DateTime? start,
}) {
  final at = start ?? DateTime.utc(2026, 8, 1, 9);
  return VisitOut(
    id: 'v-$contractorId-${at.millisecondsSinceEpoch}',
    tenantId: 't',
    jobId: 'j',
    contractorId: contractorId,
    scheduledStart: at,
    scheduledEnd: at.add(const Duration(hours: 2)),
    status: status,
    source: 'manual',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  test('countPriorClientVisits skips cancelled and ranks by count', () {
    final counts = countPriorClientVisits([
      _visit(contractorId: 'a'),
      _visit(contractorId: 'a'),
      _visit(contractorId: 'b'),
      _visit(contractorId: 'a', status: 'cancelled'),
      _visit(contractorId: 'c', status: 'cancelled'),
    ]);
    expect(counts['a'], 2);
    expect(counts['b'], 1);
    expect(counts.containsKey('c'), isFalse);
  });

  test('hasPriorClientVisits and comparePriorThenName', () {
    final counts = {'zoe': 1, 'amy': 3};
    expect(hasPriorClientVisits('amy', counts: counts), isTrue);
    expect(hasPriorClientVisits('bob', counts: counts), isFalse);

    final ids = ['zoe', 'amy', 'bob'];
    final names = {'zoe': 'Zoe', 'amy': 'Amy', 'bob': 'Bob'};
    ids.sort(
      (a, b) => comparePriorThenName(
        aId: a,
        bId: b,
        aName: names[a]!,
        bName: names[b]!,
        counts: counts,
        nameCompare: compareNames,
      ),
    );
    expect(ids, ['amy', 'zoe', 'bob']);
  });

  test('workedWithClientLabel constant', () {
    expect(workedWithClientLabel, 'Worked with client');
  });
}
