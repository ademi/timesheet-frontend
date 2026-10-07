import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/controllers/requirement_draft.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/widgets/client_requirement_editors.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

const _planMgmtReq = ClientTypeRequirement(
  requirementKey: 'plan_management',
  label: 'Plan management',
  sortOrder: 0,
  kind: 'field',
  captureModes: ['field'],
  fieldSchemaJson: {
    'options': [
      {'value': 'plan_managed', 'label': 'Plan Managed'},
      {'value': 'ndia', 'label': 'NDIA'},
      {'value': 'self_managed', 'label': 'Self Managed'},
    ],
  },
  isRequired: true,
  valueType: 'select',
);

void main() {
  late ClientsController controller;
  late RequirementDraft draft;

  setUp(() {
    Get.testMode = true;
    final session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    controller = ClientsController(
      repository: _MockClientsRepository(),
      session: session,
      jobsRepository: _MockJobsRepository(),
    );
    draft = RequirementDraft(_planMgmtReq);
  });

  tearDown(() {
    draft.dispose();
    Get.reset();
  });

  testWidgets('selecting Plan Managed stores plan_managed wire value', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ClientRequirementEditor(controller: controller, draft: draft),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    expect(find.text('Plan Managed').hitTestable(), findsWidgets);
    await tester.tap(find.text('Plan Managed').last);
    await tester.pumpAndSettle();

    expect(draft.textCtrl.text, 'plan_managed');
    expect(find.text('plan_managed'), findsNothing);
    expect(find.text('Plan Managed'), findsOneWidget);
  });
}
