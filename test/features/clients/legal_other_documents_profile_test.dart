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

const _legalOtherReq = ClientTypeRequirement(
  requirementKey: OnboardingKeys.legalOtherDocuments,
  label: 'Other legal documents',
  helpText: 'Optional extra legal PDFs (guardianship, court order, etc.)',
  sortOrder: 53,
  kind: 'field',
  captureModes: ['field'],
  fieldSchemaJson: {'schema': 'legal_other_documents_v1'},
  isRequired: false,
  valueType: 'json',
  sensitivityClass: 'confidential',
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
    draft = RequirementDraft(_legalOtherReq);
  });

  tearDown(() {
    draft.dispose();
    Get.reset();
  });

  test('applyFact hydrates legal_other_documents entries', () {
    draft.applyFact(
      const ClientProfileFactOut(
        requirementKey: OnboardingKeys.legalOtherDocuments,
        valueJson: [
          {
            'type': 'court_order',
            'label': 'Court order',
            'document_id': 'doc-court-1',
          },
          {
            'type': 'other',
            'label': 'Custom guardianship note',
            'document_id': 'doc-other-1',
          },
        ],
      ),
    );

    expect(draft.legalOtherDocs, hasLength(2));
    expect(draft.legalOtherDocs[0].displayLabel, 'Court order');
    expect(draft.legalOtherDocs[0].documentId, 'doc-court-1');
    expect(draft.legalOtherDocs[1].displayLabel, 'Custom guardianship note');
    expect(draft.fieldValueJson, isA<List>());
    expect((draft.fieldValueJson as List), hasLength(2));
  });

  testWidgets(
    'Profile & docs renders legal other labels + Download affordance',
    (tester) async {
      draft.applyFact(
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.legalOtherDocuments,
          valueJson: [
            {
              'type': 'guardianship_order',
              'label': 'Guardianship order',
              'document_id': 'doc-guard-1',
            },
            {
              'type': 'other',
              'label': 'Tribunal letter',
              'document_id': 'doc-other-2',
            },
          ],
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

      expect(find.text('Other legal documents'), findsOneWidget);
      expect(find.text('Guardianship order'), findsOneWidget);
      expect(find.text('Tribunal letter'), findsOneWidget);
      expect(find.text('Download'), findsNWidgets(2));
      expect(find.byIcon(Icons.download_outlined), findsNWidgets(2));
      // Must not dump raw JSON into a text field.
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('empty legal_other_documents shows muted empty copy', (
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

    expect(find.text('No other legal documents on file.'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
  });
}
