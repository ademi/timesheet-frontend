import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/clients/controllers/support_plan_controller.dart';
import 'package:rostiq/features/clients/data/models/strengths_needs_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/strengths_needs_keys.dart';
import 'package:rostiq/features/clients/widgets/support_plan_sn_section.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

final _now = DateTime.utc(2026, 8, 30, 9);

StrengthsNeedsDto _assessment({
  required String id,
  required String status,
  bool isCurrent = false,
}) {
  return StrengthsNeedsDto(
    id: id,
    clientId: 'client-1',
    status: status,
    isCurrent: isCurrent,
    body: const StrengthsNeedsBody(
      sections: {StrengthsNeedsKeys.livingSkills: 'Can cook meals'},
    ),
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late _MockClientsRepository mock;
  late SupportPlanController planController;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    mock = _MockClientsRepository();
    planController = SupportPlanController(repository: mock, clientId: 'client-1');
    Get.put<ClientsRepository>(mock);
  });

  tearDown(() {
    planController.onClose();
    Get.reset();
  });

  testWidgets('shows draft and current submitted statuses together', (
    tester,
  ) async {
    final submitted = _assessment(
      id: 'sn-submitted',
      status: StrengthsNeedsKeys.statusSubmitted,
      isCurrent: true,
    );
    final draft = _assessment(
      id: 'sn-draft',
      status: StrengthsNeedsKeys.statusDraft,
    );

    when(() => mock.getCurrentStrengthsNeeds('client-1'))
        .thenAnswer((_) async => submitted);
    when(() => mock.listStrengthsNeeds('client-1'))
        .thenAnswer((_) async => [draft, submitted]);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SupportPlanSnSection(
            planController: planController,
            clientId: 'client-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Draft in progress'), findsOneWidget);
    expect(find.textContaining('Submitted (current)'), findsOneWidget);
    expect(find.text('Edit assessment'), findsOneWidget);
    expect(find.text('Import to plan'), findsOneWidget);
  });

  testWidgets('import hidden when only a draft exists', (tester) async {
    final draft = _assessment(
      id: 'sn-draft',
      status: StrengthsNeedsKeys.statusDraft,
    );

    when(() => mock.getCurrentStrengthsNeeds('client-1')).thenThrow(
      const AppFailure(
        code: 'not_found',
        message: 'Not found',
        presentation: AppFailurePresentation.inline,
        statusCode: 404,
      ),
    );
    when(() => mock.listStrengthsNeeds('client-1'))
        .thenAnswer((_) async => [draft]);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SupportPlanSnSection(
            planController: planController,
            clientId: 'client-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Draft in progress'), findsOneWidget);
    expect(find.text('Import to plan'), findsNothing);
  });
}
