import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/support_plan_controller.dart';
import 'package:rostiq/features/clients/data/models/budget_summary_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late _MockClientsRepository repository;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    repository = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
  });

  tearDown(Get.reset);

  test('loads budget summary when user has budget access', () async {
    const summary = BudgetSummaryOut(
      clientId: 'client-1',
      envelopes: [
        BudgetEnvelopeOut(key: 'core', declared: 100, spent: 25, remaining: 75),
      ],
    );
    when(
      () => repository.getBudgetSummary('client-1'),
    ).thenAnswer((_) async => summary);
    final controller = SupportPlanController(
      repository: repository,
      session: session,
      clientId: 'client-1',
    );

    await controller.loadBudgetSummary();

    expect(controller.budgetSummary.value, same(summary));
    expect(controller.isLoadingBudget.value, isFalse);
  });

  test(
    'does not request budget without clients.read or billing.view',
    () async {
      when(() => session.hasPermission(any())).thenReturn(false);
      final controller = SupportPlanController(
        repository: repository,
        session: session,
        clientId: 'client-1',
      );

      await controller.loadBudgetSummary();

      verifyNever(() => repository.getBudgetSummary(any()));
      expect(controller.budgetSummary.value, isNull);
    },
  );
}
