import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/features/clients/controllers/support_plan_clinical_store.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/models/identity_card_attachment.dart';
import 'package:rostiq/features/clients/utils/clinical_keys.dart';
import 'package:rostiq/features/clients/widgets/support_plan_clinical_section.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ProfileFactUpsert(valueJson: true));
    registerFallbackValue(
      const UploadUrlRequest(
        ownerType: 'client',
        ownerId: 'c1',
        filename: 'x.pdf',
        contentType: 'application/pdf',
        sizeBytes: 1,
        category: 'medical_report',
      ),
    );
  });

  late _MockClientsRepository mock;

  setUp(() {
    mock = _MockClientsRepository();
  });

  test('applyProfileBundle sets bspOnFile from facts', () {
    final store = SupportPlanClinicalStore(repository: mock);
    store.applyProfileBundle(
      const ClientProfileBundle(
        facts: [
          ClientProfileFactOut(
            requirementKey: ClinicalKeys.bspOnFile,
            valueJson: true,
          ),
          ClientProfileFactOut(
            requirementKey: ClinicalKeys.nutritionChecklistOnFile,
            valueJson: false,
          ),
        ],
      ),
    );
    expect(store.bspOnFile.value, isTrue);
    expect(store.nutritionChecklistOnFile.value, isFalse);
    expect(store.hasHydrated, isTrue);
  });

  test('applyProfileBundle detects PDF on file from document_id', () {
    final store = SupportPlanClinicalStore(repository: mock);
    store.applyProfileBundle(
      const ClientProfileBundle(
        facts: [
          ClientProfileFactOut(
            requirementKey: ClinicalKeys.behaviourSupportPlanDoc,
            documentId: 'doc-bsp-1',
          ),
        ],
      ),
    );
    expect(store.bspPdfOnFile.value, isTrue);
  });

  test('applyProfileBundle clears pending PDFs', () {
    final store = SupportPlanClinicalStore(repository: mock);
    store.pendingMedical.value = const PendingIdentityCardFile(
      name: 'medical.pdf',
      bytes: [1],
      contentType: 'application/pdf',
    );
    store.applyProfileBundle(const ClientProfileBundle(facts: []));
    expect(store.pendingMedical.value, isNull);
  });

  test('pickMedicalPdf holds locally and does not set isBusy or toggle', () async {
    final store = SupportPlanClinicalStore(
      repository: mock,
      documentPipeline: _MockDocumentPipeline(),
      pickPdfBytes: () async => (name: 'medical.pdf', bytes: [1, 2, 3]),
    );
    store.applyProfileBundle(const ClientProfileBundle(facts: []));
    store.bspOnFile.value = false;

    await store.pickMedicalPdf();
    await store.pickBspPdf();

    expect(store.pendingMedical.value?.name, 'medical.pdf');
    expect(store.pendingBsp.value?.name, 'medical.pdf');
    expect(store.isBusy.value, isFalse);
    expect(store.bspOnFile.value, isFalse);
    expect(store.medicalPdfOnFile.value, isFalse);
    expect(store.bspPdfOnFile.value, isFalse);
    verifyNever(() => mock.upsertProfileFact(any(), any(), any()));
  });

  test('persistFacts upserts boolean on-file keys', () async {
    final store = SupportPlanClinicalStore(repository: mock);
    store.applyProfileBundle(const ClientProfileBundle(facts: []));
    store.bspOnFile.value = true;
    store.nutritionChecklistOnFile.value = true;
    store.hazardChecklistOnFile.value = false;

    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async => const ClientProfileFactOut(requirementKey: 'x'));

    final failed = await store.persistFacts(clientId: 'c1');
    expect(failed, isEmpty);
    verify(
      () => mock.upsertProfileFact(
        'c1',
        ClinicalKeys.bspOnFile,
        any(that: predicate<ProfileFactUpsert>((u) => u.valueJson == true)),
      ),
    ).called(1);
  });

  test('persistFacts uploads pending PDFs then clears pending', () async {
    final pipeline = _MockDocumentPipeline();
    when(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer(
      (_) async => const DocumentOut(
        id: 'doc-med-1',
        ownerType: 'client',
        ownerId: 'c1',
        filename: 'medical.pdf',
        contentType: 'application/pdf',
        sizeBytes: 3,
        scanStatus: 'clean',
      ),
    );
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async => const ClientProfileFactOut(requirementKey: 'x'));

    final store = SupportPlanClinicalStore(
      repository: mock,
      documentPipeline: pipeline,
      pickPdfBytes: () async => (name: 'medical.pdf', bytes: [1, 2, 3]),
    );
    store.applyProfileBundle(const ClientProfileBundle(facts: []));
    await store.pickMedicalPdf();

    final failed = await store.persistFacts(clientId: 'c1');
    expect(failed, isEmpty);
    expect(store.pendingMedical.value, isNull);
    expect(store.medicalPdfOnFile.value, isTrue);
    expect(store.isBusy.value, isFalse);
    verify(
      () => mock.upsertProfileFact(
        'c1',
        ClinicalKeys.medicalReport,
        any(
          that: predicate<ProfileFactUpsert>((u) => u.documentId == 'doc-med-1'),
        ),
      ),
    ).called(1);
  });

  testWidgets('Clinical section shows BSP and nutrition rows', (tester) async {
    final store = SupportPlanClinicalStore(repository: mock);
    store.applyProfileBundle(const ClientProfileBundle(facts: []));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportPlanClinicalSection(store: store),
        ),
      ),
    );

    expect(find.text('Behaviour support plan'), findsOneWidget);
    expect(find.text('Nutrition checklist'), findsOneWidget);
    expect(find.text('Hazard checklist'), findsOneWidget);
  });

  testWidgets('Clinical section shows pending filename', (tester) async {
    final store = SupportPlanClinicalStore(repository: mock);
    store.applyProfileBundle(const ClientProfileBundle(facts: []));
    store.pendingMedical.value = const PendingIdentityCardFile(
      name: 'pending-med.pdf',
      bytes: [1],
      contentType: 'application/pdf',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportPlanClinicalSection(store: store),
        ),
      ),
    );

    expect(find.text('pending-med.pdf'), findsOneWidget);
  });
}
