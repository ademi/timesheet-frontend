import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/billing/controllers/staff_invoices_controller.dart';
import 'package:rostiq/features/billing/data/models/invoice_export_models.dart';
import 'package:rostiq/features/billing/data/repositories/billing_repository.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late _MockBillingRepository billing;
  late _MockVisitsRepository visits;
  late _MockSessionService session;
  late StaffInvoicesController controller;

  setUpAll(() {
    registerFallbackValue(
      const InvoiceExportCreateRequest(visitIds: <String>[]),
    );
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    billing = _MockBillingRepository();
    visits = _MockVisitsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => billing.listExports(limit: any(named: 'limit')),
    ).thenAnswer((_) async => <InvoiceExportOut>[]);
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
      ),
    ).thenAnswer((_) async => <VisitOut>[]);
    controller = StaffInvoicesController(
      billing: billing,
      visits: visits,
      session: session,
      successNotifier: (_, __) {},
    );
  });

  tearDown(Get.reset);

  test(
    'createExport posts selected visits, clears selection, reloads list',
    () async {
      final first = _visit('visit-1');
      final second = _visit('visit-2');
      controller.completedVisits.assignAll([first, second]);
      controller.selectedVisitIds.addAll({first.id, second.id});
      when(
        () => billing.createExport(any()),
      ).thenAnswer((_) async => _export(id: 'export-1', lineCount: 2));

      await controller.createExport();

      final request =
          verify(() => billing.createExport(captureAny())).captured.single
              as InvoiceExportCreateRequest;
      expect(request.visitIds, containsAll(<String>['visit-1', 'visit-2']));
      expect(request.visitIds, hasLength(2));
      expect(controller.selectedVisitIds, isEmpty);
      expect(controller.tabIndex.value, 0);
      verify(() => billing.listExports(limit: 100)).called(1);
    },
  );

  test('createExport is blocked without billing.manage', () async {
    when(
      () => session.hasPermission(AppPermissions.billingManage),
    ).thenReturn(false);
    controller.completedVisits.assignAll([_visit('visit-1')]);
    controller.selectedVisitIds.add('visit-1');

    await controller.createExport();

    verifyNever(() => billing.createExport(any()));
  });
}

VisitOut _visit(String id) {
  final now = DateTime.utc(2026, 9, 10);
  return VisitOut(
    id: id,
    tenantId: 'tenant-1',
    jobId: 'job-1',
    contractorId: 'contractor-1',
    scheduledStart: now,
    scheduledEnd: now.add(const Duration(hours: 1)),
    status: 'completed',
    source: 'manual',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: now,
    updatedAt: now,
    jobTitle: 'Community access',
  );
}

InvoiceExportOut _export({required String id, required int lineCount}) {
  final now = DateTime.utc(2026, 9, 10);
  return InvoiceExportOut(
    id: id,
    tenantId: 'tenant-1',
    status: 'finalized',
    lineCount: lineCount,
    totalAmount: 100,
    currencyCode: 'AUD',
    createdAt: now,
    updatedAt: now,
  );
}
