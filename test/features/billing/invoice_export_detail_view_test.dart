import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/billing/controllers/invoice_export_detail_controller.dart';
import 'package:rostiq/features/billing/data/exported_visit_ids_store.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/repositories/billing_repository.dart';
import 'package:rostiq/features/billing/views/invoice_export_detail_view.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 8, 13, 10);

InvoiceExportLineOut _line({String? shiftParticipantId}) {
  return InvoiceExportLineOut(
    id: 'line-1',
    visitId: 'visit-1',
    clientName: 'Maya Smith',
    participantNdisNumber: '430000000',
    supportItemNumber: '01_011_0107_1_1',
    supportItemName: 'Self care',
    serviceDate: DateTime.utc(2026, 8, 13),
    quantity: 2,
    unit: 'H',
    unitPrice: 32.73,
    lineAmount: 65.46,
    priceTier: PriceTier.national,
    shiftParticipantId: shiftParticipantId,
  );
}

InvoiceExportOut _export({
  required List<InvoiceExportLineOut> lines,
  List<BudgetWarningOut> budgetWarnings = const [],
}) {
  return InvoiceExportOut(
    id: 'export-1',
    tenantId: 'tenant-1',
    status: 'finalized',
    lineCount: lines.length,
    totalAmount: lines.fold<double>(0, (sum, line) => sum + line.lineAmount),
    currencyCode: 'AUD',
    createdAt: _now,
    updatedAt: _now,
    finalizedAt: _now,
    lines: lines,
    budgetWarnings: budgetWarnings,
  );
}

void main() {
  late _MockBillingRepository billing;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    billing = _MockBillingRepository();
    session = _MockSessionService();
    when(() => session.canViewBilling).thenReturn(true);
    when(() => session.canManageBilling).thenReturn(false);
  });

  tearDown(Get.reset);

  Future<void> pumpDetail(
    WidgetTester tester, {
    required InvoiceExportOut export,
  }) async {
    when(
      () => billing.getInvoiceExport('export-1'),
    ).thenAnswer((_) async => export);
    Get.parameters = {'id': 'export-1'};
    Get.put(
      InvoiceExportDetailController(
        repository: billing,
        session: session,
        exportedVisitIds: ExportedVisitIdsStore(),
      ),
    );
    await tester.pumpWidget(
      const GetMaterialApp(home: InvoiceExportDetailView()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows Group share caption when shiftParticipantId set', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      export: _export(lines: [_line(shiftParticipantId: 'sp-1')]),
    );
    expect(find.text('Maya Smith'), findsOneWidget);
    expect(find.text('Group share'), findsOneWidget);
  });

  testWidgets('hides Group share caption for single-client lines', (
    tester,
  ) async {
    await pumpDetail(tester, export: _export(lines: [_line()]));
    expect(find.text('Maya Smith'), findsOneWidget);
    expect(find.text('Group share'), findsNothing);
  });

  testWidgets('shows amber budget warning returned by export GET', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      export: _export(
        lines: [_line()],
        budgetWarnings: const [
          BudgetWarningOut(
            code: 'budget_exceeded',
            clientId: 'client-1',
            envelope: 'core',
            remainingAfter: -15,
          ),
        ],
      ),
    );

    expect(find.text('Budget warning'), findsOneWidget);
    expect(
      find.text(
        'Core budget exceeded by AUD 15.00. The export still succeeded.',
      ),
      findsOneWidget,
    );
  });
}
