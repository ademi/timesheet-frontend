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

const _referralReq = ClientTypeRequirement(
  requirementKey: 'referral_source',
  label: 'Referred by',
  sortOrder: 0,
  kind: 'field',
  captureModes: ['field'],
  fieldSchemaJson: {
    'options': ['Friend/Family', 'Self Referred', 'Other'],
  },
  isRequired: false,
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
    draft = RequirementDraft(_referralReq);
    draft.textCtrl.text = 'Community Centre';
  });

  tearDown(() {
    draft.dispose();
    Get.reset();
  });

  testWidgets('select requirement with unknown stored value shows Other', (
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

    expect(tester.takeException(), isNull);
    expect(find.text('Other'), findsWidgets);
    expect(find.text('Community Centre'), findsOneWidget);
  });
}
