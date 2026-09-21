import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/controllers/requirement_draft.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';
import 'package:rostiq/features/clients/widgets/client_requirement_editors.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

const _disabilityReq = ClientTypeRequirement(
  requirementKey: OnboardingKeys.disabilityCard,
  label: 'Disability card',
  sortOrder: 62,
  kind: 'document',
  captureModes: ['field', 'document'],
  fieldSchemaJson: {
    'placeholder': 'Disability card number',
    'accept': [
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
    ],
  },
  isRequired: false,
  valueType: 'text',
  documentCategory: OnboardingKeys.disabilityCard,
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
    draft = RequirementDraft(_disabilityReq);
  });

  tearDown(() {
    draft.dispose();
    Get.reset();
  });

  test('applyFact hydrates disability card number into draft', () {
    draft.applyFact(
      const ClientProfileFactOut(
        requirementKey: OnboardingKeys.disabilityCard,
        valueJson: 'DC-42',
      ),
    );
    expect(draft.textCtrl.text, 'DC-42');
    expect(draft.fieldValueJson, 'DC-42');
  });

  testWidgets('Profile & docs shows disability card number field', (
    tester,
  ) async {
    draft.applyFact(
      const ClientProfileFactOut(
        requirementKey: OnboardingKeys.disabilityCard,
        valueJson: 'DC-42',
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ClientRequirementEditor(controller: controller, draft: draft),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DC-42'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
