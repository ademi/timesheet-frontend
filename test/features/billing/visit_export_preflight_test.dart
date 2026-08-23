import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/utils/visit_export_preflight.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';

final _start = DateTime.utc(2026, 8, 13, 9);
final _end = DateTime.utc(2026, 8, 13, 11);

VisitOut _visit({
  String status = 'completed',
  String? supportItemCode,
  String? priceTierOverride,
  List<VisitTaskOut> tasks = const [],
}) {
  return VisitOut(
    id: 'visit-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    contractorId: 'contractor-1',
    scheduledStart: _start,
    scheduledEnd: _end,
    status: status,
    source: 'manual',
    latitude: 0,
    longitude: 0,
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: _start,
    updatedAt: _start,
    supportItemCode: supportItemCode,
    priceTierOverride: priceTierOverride,
    tasks: tasks,
  );
}

void main() {
  test('blocks export when visit-level support item missing', () {
    final preflight = buildVisitExportPreflight(_visit());
    expect(preflight.isReady, isFalse);
    expect(
      preflight.checks.any((c) => c.label == 'Visit support item'),
      isTrue,
    );
  });

  test('ready with visit support item and tier override', () {
    final preflight = buildVisitExportPreflight(
      _visit(
        supportItemCode: '01_011_0107_1_1',
        priceTierOverride: PriceTier.national,
      ),
    );
    expect(preflight.isReady, isTrue);
  });

  test('blocks coded tasks missing billable minutes', () {
    final preflight = buildVisitExportPreflight(
      _visit(
        tasks: [
          VisitTaskOut(
            id: 'task-1',
            visitId: 'visit-1',
            title: 'Care',
            sortOrder: 0,
            isDone: true,
            supportItemCode: '01_011_0107_1_1',
          ),
        ],
      ),
    );
    expect(preflight.isReady, isFalse);
  });

  test('ready for multi-line when tasks have minutes', () {
    final preflight = buildVisitExportPreflight(
      _visit(
        tasks: [
          VisitTaskOut(
            id: 'task-1',
            visitId: 'visit-1',
            title: 'Care',
            sortOrder: 0,
            isDone: true,
            supportItemCode: '01_011_0107_1_1',
            billableMinutes: 60,
          ),
        ],
      ),
    );
    expect(preflight.isReady, isTrue);
  });
}
