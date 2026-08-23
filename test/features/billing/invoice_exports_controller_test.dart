import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/billing/controllers/invoice_exports_controller.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/repositories/billing_repository.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 8, 13, 10);
final _visitStart = DateTime.utc(2026, 8, 13, 9);
final _visitEnd = DateTime.utc(2026, 8, 13, 11);

InvoiceExportOut _export({String id = 'export-1', String status = 'finalized'}) {
  return InvoiceExportOut(
    id: id,
    tenantId: 'tenant-1',
    status: status,
    lineCount: 2,
    totalAmount: 130.94,
    currencyCode: 'AUD',
    createdAt: _now,
    updatedAt: _now,
    finalizedAt: _now,
  );
}

VisitOut _exportableVisit({String id = 'visit-1'}) {
  return VisitOut(
    id: id,
    tenantId: 'tenant-1',
    jobId: 'job-1',
    contractorId: 'contractor-1',
    scheduledStart: _visitStart,
    scheduledEnd: _visitEnd,
    status: 'completed',
    source: 'manual',
    latitude: 0,
    longitude: 0,
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: _visitStart,
    updatedAt: _visitStart,
    supportItemCode: '01_011_0107_1_1',
    priceTierOverride: PriceTier.national,
  );
}

InvoiceExportsController _controller({
  required _MockBillingRepository repository,
  required _MockVisitsRepository visitsRepository,
  required _MockSessionService session,
  bool init = false,
}) {
  final controller = InvoiceExportsController(
    repository: repository,
    visitsRepository: visitsRepository,
    session: session,
  );
  if (init) {
    controller.onInit();
  }
  return controller;
}

void main() {
  late _MockBillingRepository repository;
  late _MockVisitsRepository visitsRepository;
  late _MockSessionService session;

  setUpAll(() {
    registerFallbackValue(
      const InvoiceExportCreateRequest(visitIds: ['visit-1']),
    );
  });

  setUp(() {
    Get.testMode = true;
    repository = _MockBillingRepository();
    visitsRepository = _MockVisitsRepository();
    session = _MockSessionService();
    when(() => session.canViewBilling).thenReturn(true);
    when(() => session.canManageBilling).thenReturn(false);
  });

  tearDown(Get.reset);

  group('InvoiceExportsController', () {
    test('loadExports fetches exports when user can view billing', () async {
      when(
        () => repository.listInvoiceExports(limit: any(named: 'limit')),
      ).thenAnswer((_) async => [_export()]);

      final controller = _controller(
        repository: repository,
        visitsRepository: visitsRepository,
        session: session,
      );
      controller.onInit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.exports, hasLength(1));
      expect(controller.exports.single.totalAmount, 130.94);
      verify(() => repository.listInvoiceExports(limit: 100)).called(1);
    });

    test('loadExports surfaces permission error when billing.view missing', () async {
      when(() => session.canViewBilling).thenReturn(false);

      final controller = _controller(
        repository: repository,
        visitsRepository: visitsRepository,
        session: session,
      );
      await controller.loadExports();

      expect(controller.exports, isEmpty);
      expect(controller.errorMessage.value, contains('billing.view'));
      verifyNever(() => repository.listInvoiceExports(limit: any(named: 'limit')));
    });

    test('loadExportableVisits loads completed visits for period', () async {
      when(() => session.canManageBilling).thenReturn(true);
      when(
        () => visitsRepository.listVisits(
          from: any(named: 'from'),
          to: any(named: 'to'),
          status: 'completed',
          limit: 200,
        ),
      ).thenAnswer((_) async => [_exportableVisit()]);

      final controller = _controller(
        repository: repository,
        visitsRepository: visitsRepository,
        session: session,
        init: true,
      );
      await controller.loadExportableVisits();

      expect(controller.exportableVisits, hasLength(1));
      expect(controller.exportableVisits.single.id, 'visit-1');
    });

    test('createExport posts visit ids and clears selection on success', () async {
      when(() => session.canManageBilling).thenReturn(true);
      when(
        () => visitsRepository.listVisits(
          from: any(named: 'from'),
          to: any(named: 'to'),
          status: 'completed',
          limit: 200,
        ),
      ).thenAnswer((_) async => [_exportableVisit()]);
      when(
        () => repository.createInvoiceExport(any()),
      ).thenAnswer((_) async => _export(id: 'export-new'));
      when(
        () => repository.listInvoiceExports(limit: any(named: 'limit')),
      ).thenAnswer((_) async => [_export(id: 'export-new')]);

      final controller = _controller(
        repository: repository,
        visitsRepository: visitsRepository,
        session: session,
        init: true,
      );
      await controller.loadExportableVisits();
      controller.selectedVisitIds.add('visit-1');
      expect(controller.selectedVisitsReady, isTrue);

      await controller.createExport();

      final captured = verify(
        () => repository.createInvoiceExport(captureAny()),
      ).captured.single as InvoiceExportCreateRequest;
      expect(captured.visitIds, ['visit-1']);
      expect(controller.selectedVisitIds, isEmpty);
      expect(controller.lastVisitErrors, isEmpty);
      expect(controller.tabIndex.value, 0);
    });

    test('createExport maps visit_errors and excludes already exported visits', () async {
      when(() => session.canManageBilling).thenReturn(true);
      when(
        () => visitsRepository.listVisits(
          from: any(named: 'from'),
          to: any(named: 'to'),
          status: 'completed',
          limit: 200,
        ),
      ).thenAnswer(
        (_) async => [
          _exportableVisit(id: 'visit-1'),
          _exportableVisit(id: 'visit-2'),
        ],
      );
      when(() => repository.createInvoiceExport(any())).thenThrow(
        const AppFailure(
          code: 'batch_export_failed',
          message: 'Some visits could not be exported.',
          presentation: AppFailurePresentation.inline,
          visitErrors: [
            {
              'visit_id': 'visit-1',
              'code': 'visit_already_exported',
              'message': 'Already included in an export — void that export to rebill.',
            },
          ],
        ),
      );

      final controller = _controller(
        repository: repository,
        visitsRepository: visitsRepository,
        session: session,
        init: true,
      );
      await controller.loadExportableVisits();
      controller.selectedVisitIds.addAll(['visit-1', 'visit-2']);

      await controller.createExport();

      expect(controller.lastVisitErrors, hasLength(1));
      expect(controller.lastVisitErrors.single.visitId, 'visit-1');
      expect(controller.excludedVisitIds, contains('visit-1'));
      expect(controller.exportableVisits.map((v) => v.id), ['visit-2']);
      expect(controller.selectedVisitIds, ['visit-2']);
    });
  });

  test('invoiceExportStatusLabel formats known statuses', () {
    expect(invoiceExportStatusLabel('finalized'), 'Finalized');
    expect(invoiceExportStatusLabel('void'), 'Void');
    expect(invoiceExportStatusLabel('pending'), 'pending');
  });
}
