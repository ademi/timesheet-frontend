import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/controllers/requirement_draft.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';
import 'package:rostiq/features/clients/widgets/client_requirement_editors.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _FakeClientUpdateRequest extends Fake implements ClientUpdateRequest {}

class _FakeClientLegalAcceptRequest extends Fake
    implements ClientLegalAcceptRequest {}

class _FakeUploadUrlRequest extends Fake implements UploadUrlRequest {}

final _now = DateTime.utc(2026, 8, 27, 9);

const _consentReq = ClientTypeRequirement(
  requirementKey: OnboardingKeys.consentAgreement,
  label: 'Consent agreement',
  sortOrder: 0,
  kind: 'legal',
  captureModes: const [],
  fieldSchemaJson: <String, dynamic>{},
  isRequired: false,
  legalDocKey: OnboardingKeys.consentAgreementDocKey,
  documentCategory: 'consent',
);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Demo Patient',
  status: 'active',
  email: 'demo@example.com',
  phone: '+61400000100',
  clientTypeId: 'type-patient',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockClientsRepository clients;
  late _MockJobsRepository jobs;
  late _MockSessionService session;
  late _MockDocumentPipeline pipeline;
  late ClientsController controller;

  setUpAll(() {
    registerFallbackValue(_FakeClientUpdateRequest());
    registerFallbackValue(_FakeClientLegalAcceptRequest());
    registerFallbackValue(_FakeUploadUrlRequest());
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clients = _MockClientsRepository();
    jobs = _MockJobsRepository();
    session = _MockSessionService();
    pipeline = _MockDocumentPipeline();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => clients.listClients()).thenAnswer((_) async => [_client]);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    when(() => clients.getClient(_client.id)).thenAnswer((_) async => _client);
    when(() => clients.getClientProfile(_client.id)).thenAnswer(
      (_) async => const ClientProfileBundle(facts: []),
    );
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.listContacts(any())).thenAnswer((_) async => []);
    when(() => clients.listSupportPlans(any())).thenAnswer((_) async => []);
    controller = ClientsController(
      repository: clients,
      session: session,
      documentPipeline: pipeline,
      jobsRepository: jobs,
    );
    controller.selected.value = _client;
    Get.put(controller);
  });

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  testWidgets('Legal block shows Upload PDF as primary affordance', (
    tester,
  ) async {
    final draft = RequirementDraft(_consentReq);
    draft.legalDoc.value = const ClientLegalDocumentCurrent(
      id: 'legal-v1',
      title: 'Consent',
      contentMd: '# Consent',
    );
    addTearDown(draft.dispose);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClientRequirementEditor(controller: controller, draft: draft),
          ),
        ),
      ),
    );

    expect(find.byKey(ClientRequirementEditor.legalUploadPdfKey), findsOneWidget);
    expect(find.text('Upload PDF'), findsOneWidget);
    expect(find.text('Consent agreement'), findsOneWidget);
  });

  test('applyLegal hydrates documentId and uploaded_scan method', () {
    final draft = RequirementDraft(_consentReq);
    addTearDown(draft.dispose);
    expect(draft.method.value, 'staff_recorded');

    draft.applyLegal(
      const ClientLegalAcceptanceOut(
        requirementKey: OnboardingKeys.consentAgreement,
        participantOrRepName: 'Sam Parent',
        method: 'uploaded_scan',
        documentId: 'doc-existing',
      ),
    );

    expect(draft.method.value, 'uploaded_scan');
    expect(draft.existingDocumentId.value, 'doc-existing');
  });

  testWidgets(
    'saveClientTypeProfile acceptClientLegal sends documentId via requirementKey',
    (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      when(() => clients.patchClient(any(), any())).thenAnswer((_) async => _client);
      when(() => clients.listClientTypes()).thenAnswer((_) async => []);
      when(
        () => clients.listTypeRequirements(any()),
      ).thenAnswer((_) async => const []);
      when(
        () => pipeline.uploadEvidence(
          request: any(named: 'request'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer(
        (_) async => const DocumentOut(
          id: 'doc-consent-1',
          ownerType: 'client',
          ownerId: 'client-1',
          filename: 'consent.pdf',
          contentType: 'application/pdf',
          sizeBytes: 3,
          scanStatus: 'clean',
        ),
      );
      when(() => clients.acceptClientLegal(any(), any(), any()))
          .thenAnswer((_) async {});

      final draft = RequirementDraft(_consentReq);
      draft.legalDoc.value = const ClientLegalDocumentCurrent(
        id: 'legal-v1',
        title: 'Consent',
        contentMd: '# Consent',
      );
      draft.participantNameCtrl.text = 'Sam Parent';
      draft.legalAccepted.value = true;
      draft.method.value = 'uploaded_scan';
      draft.localFiles.add(
        const PickedClientFile(
          name: 'consent.pdf',
          contentType: 'application/pdf',
          bytes: [1, 2, 3],
        ),
      );

      controller.selectedClientTypeId.value = 'type-patient';
      controller.requirementDrafts.assignAll([draft]);

      await controller.saveClientTypeProfile();
      await tester.pumpAndSettle();

      verify(
        () => clients.acceptClientLegal(
          _client.id,
          OnboardingKeys.consentAgreement,
          any(
            that: predicate<ClientLegalAcceptRequest>(
              (r) =>
                  r.method == 'uploaded_scan' &&
                  r.documentId == 'doc-consent-1' &&
                  (r.note == null || !r.note!.contains('document_id=')),
            ),
          ),
        ),
      ).called(1);
      verifyNever(
        () => clients.acceptClientLegal(
          any(),
          OnboardingKeys.consentAgreementDocKey,
          any(),
        ),
      );
    },
  );
}
