import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/features/clients/controllers/support_plan_clinical_store.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/clinical_keys.dart';
import 'package:rostiq/features/clients/widgets/support_plan_clinical_section.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ProfileFactUpsert(valueJson: true));
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
        any(
          that: predicate<ProfileFactUpsert>(
            (u) => u.valueJson == true,
          ),
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
          body: SupportPlanClinicalSection(store: store, clientId: 'c1'),
        ),
      ),
    );

    expect(find.text('Behaviour support plan'), findsOneWidget);
    expect(find.text('Nutrition checklist'), findsOneWidget);
    expect(find.text('Hazard checklist'), findsOneWidget);
  });
}
