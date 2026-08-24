import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/billing/controllers/invoice_export_detail_controller.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/repositories/billing_repository.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 8, 13, 10);

InvoiceExportOut _export({
  String id = 'export-1',
  String status = 'finalized',
  List<InvoiceExportLineOut> lines = const [],
}) {
  return InvoiceExportOut(
    id: id,
    tenantId: 'tenant-1',
    status: status,
    lineCount: lines.length,
    totalAmount: lines.fold<double>(
      0,
      (sum, line) => sum + line.lineAmount,
    ),
    currencyCode: 'AUD',
    createdAt: _now,
    updatedAt: _now,
    finalizedAt: status == 'finalized' ? _now : null,
    lines: lines,
  );
}

InvoiceExportLineOut _line() {
  return InvoiceExportLineOut(
    id: 'line-1',
    visitId: 'visit-1',
    clientName: 'Jane Participant',
    participantNdisNumber: '430000000',
    supportItemNumber: '01_011_0107_1_1',
    supportItemName: 'Self care',
    serviceDate: DateTime.utc(2026, 8, 13),
    quantity: 2,
    unit: 'H',
    unitPrice: 65.47,
    lineAmount: 130.94,
    priceTier: PriceTier.national,
  );
}

void main() {
  late _MockBillingRepository repository;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    repository = _MockBillingRepository();
    session = _MockSessionService();
    when(() => session.canViewBilling).thenReturn(true);
    when(() => session.canManageBilling).thenReturn(false);
  });

  tearDown(Get.reset);

  test('invoiceExportCsvFilename uses export id prefix', () {
    expect(
      invoiceExportCsvFilename('abcdef12-3456-7890-abcd-ef1234567890'),
      'invoice-export-abcdef12.csv',
    );
  });

  group('InvoiceExportDetailController', () {
    test('load fetches export by route parameter id', () async {
      when(
        () => repository.getInvoiceExport('export-42'),
      ).thenAnswer((_) async => _export(id: 'export-42', lines: [_line()]));

      Get.parameters = {'id': 'export-42'};
      final controller = InvoiceExportDetailController(
        repository: repository,
        session: session,
      );
      await controller.load();

      expect(controller.selected.value?.id, 'export-42');
      expect(controller.selected.value?.lines.single.participantNdisNumber,
          '430000000');
      verify(() => repository.getInvoiceExport('export-42')).called(1);
    });

    test('downloadCsv fetches csv from repository', () async {
      when(
        () => repository.downloadInvoiceExportCsv('export-1'),
      ).thenAnswer((_) async => 'participant_ndis_number,service_date\n');

      Get.parameters = {'id': 'export-1'};
      final controller = InvoiceExportDetailController(
        repository: repository,
        session: session,
      );
      await controller.downloadCsv();

      verify(() => repository.downloadInvoiceExportCsv('export-1')).called(1);
      expect(controller.errorMessage.value, isNull);
    });

    test('voidExport updates export when user can manage billing', () async {
      when(() => session.canManageBilling).thenReturn(true);
      when(
        () => repository.voidInvoiceExport('export-1'),
      ).thenAnswer((_) async => _export(id: 'export-1', status: 'void'));

      Get.parameters = {'id': 'export-1'};
      final controller = InvoiceExportDetailController(
        repository: repository,
        session: session,
      );
      controller.selected.value = _export(id: 'export-1');
      expect(controller.canVoid, isTrue);

      await controller.voidExport();

      expect(controller.selected.value?.isVoid, isTrue);
      verify(() => repository.voidInvoiceExport('export-1')).called(1);
    });

    test('voidExport surfaces AppFailure message', () async {
      when(() => session.canManageBilling).thenReturn(true);
      when(() => repository.voidInvoiceExport('export-1')).thenThrow(
        const AppFailure(
          code: 'export_not_voidable',
          message: 'Only finalized exports can be voided.',
          presentation: AppFailurePresentation.inline,
        ),
      );

      Get.parameters = {'id': 'export-1'};
      final controller = InvoiceExportDetailController(
        repository: repository,
        session: session,
      );
      controller.selected.value = _export(id: 'export-1');

      await controller.voidExport();

      expect(controller.errorMessage.value,
          'Only finalized exports can be voided.');
    });

    test('canVoid is false when export already void', () {
      when(() => session.canManageBilling).thenReturn(true);
      final controller = InvoiceExportDetailController(
        repository: repository,
        session: session,
      );
      controller.selected.value = _export(status: 'void');

      expect(controller.canVoid, isFalse);
    });
  });
}
