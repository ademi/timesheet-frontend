import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/clients/controllers/support_plan_controller.dart';
import 'package:rostiq/features/clients/controllers/support_plan_funding_consent_store.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/models/support_plan_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';
import 'package:rostiq/features/clients/utils/support_plan_keys.dart';
import 'package:rostiq/features/clients/widgets/support_plan_consent_section.dart';
import 'package:rostiq/features/clients/widgets/support_plan_funding_section.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

final _now = DateTime.utc(2026, 8, 27, 9);

SupportPlanDto _plan({
  String id = 'plan-1',
  String status = SupportPlanKeys.statusDraft,
}) {
  return SupportPlanDto(
    id: id,
    clientId: 'c1',
    status: status,
    body: const SupportPlanBody(),
    bodyInvalid: false,
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const ProfileFactUpsert(valueJson: true));
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(
      const UploadUrlRequest(
        ownerType: 'client',
        ownerId: 'c1',
        filename: 'x.pdf',
        contentType: 'application/pdf',
        sizeBytes: 1,
        category: 'ndis',
      ),
    );
    registerFallbackValue(
      const ClientLegalAcceptRequest(
        eventType: 'consented',
        legalDocumentVersionId: 'v1',
        participantOrRepName: 'x',
        method: 'uploaded_scan',
      ),
    );
  });

  late _MockClientsRepository mock;

  setUp(() {
    mock = _MockClientsRepository();
  });

  test('applyProfileBundle hydrates plan management and consent flags', () {
    final store = SupportPlanFundingConsentStore(repository: mock);
    store.applyProfileBundle(
      const ClientProfileBundle(
        facts: [
          ClientProfileFactOut(
            requirementKey: OnboardingKeys.planManagementType,
            valueJson: 'self_managed',
          ),
          ClientProfileFactOut(
            requirementKey: OnboardingKeys.infoShareConsent,
            valueJson: true,
          ),
        ],
        legalAcceptances: [
          ClientLegalAcceptanceOut(
            requirementKey: OnboardingKeys.consentAgreement,
          ),
          ClientLegalAcceptanceOut(
            requirementKey: OnboardingKeys.serviceAgreement,
          ),
        ],
      ),
    );
    expect(store.planManagementType.value, 'self_managed');
    expect(store.infoShareConsent.value, isTrue);
    expect(store.consentAgreementComplete.value, isTrue);
    expect(store.serviceAgreementComplete.value, isTrue);
    expect(store.hasHydrated, isTrue);
    store.dispose();
  });

  test('validateFunding requires plan manager name when plan_managed', () {
    final store = SupportPlanFundingConsentStore(repository: mock);
    store.planManagementType.value = 'plan_managed';
    store.planManagerNameCtrl.text = '';
    expect(
      store.validateFunding(requirePlanType: true),
      contains('Plan manager name'),
    );
    store.dispose();
  });

  test('validateFunding requires other detail when claiming=other', () {
    final store = SupportPlanFundingConsentStore(repository: mock);
    store.preferredClaimingMethod.value = 'other';
    store.preferredClaimingOtherCtrl.text = '';
    expect(store.validateFunding(requirePlanType: false), contains('claiming'));
    store.dispose();
  });

  test('D6=B save draft allows unset plan type; activate requires it', () {
    final store = SupportPlanFundingConsentStore(repository: mock);
    store.planManagementType.value = null;
    expect(store.validateFunding(requirePlanType: false), isNull);
    expect(store.validateFunding(requirePlanType: true), isNotNull);
    store.dispose();
  });

  test(
    'D5=A persistFacts upserts owned keys including false booleans',
    () async {
      final putKeys = <String>[];
      final values = <String, Object?>{};
      when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
        final key = inv.positionalArguments[1] as String;
        final body = inv.positionalArguments[2] as ProfileFactUpsert;
        putKeys.add(key);
        values[key] = body.valueJson;
        return Future.value();
      });

      final store = SupportPlanFundingConsentStore(repository: mock);
      store.hasHydrated = true;
      store.planManagementType.value = 'ndia';
      store.infoShareConsent.value = false;
      store.specificSupportsConsent.value = false;

      final failed = await store.persistFacts(clientId: 'c1');
      expect(failed, isEmpty);
      expect(putKeys, contains(OnboardingKeys.planManagementType));
      expect(putKeys, contains(OnboardingKeys.infoShareConsent));
      expect(values[OnboardingKeys.infoShareConsent], isFalse);
      store.dispose();
    },
  );

  test('applyProfileBundle hydrates ndis_plan_budgets JSON', () {
    final store = SupportPlanFundingConsentStore(repository: mock);
    store.applyProfileBundle(
      const ClientProfileBundle(
        facts: [
          ClientProfileFactOut(
            requirementKey: OnboardingKeys.ndisPlanBudgets,
            valueJson: {
              'budgets': [
                {'type': 'core', 'amount_dollars': 5000},
                {'type': 'other', 'amount_dollars': 200, 'label': 'Transport'},
              ],
            },
          ),
        ],
      ),
    );
    expect(store.budgetCoreCtrl.text, '5000');
    expect(store.budgetOtherLabelCtrl.text, 'Transport');
    expect(store.budgetOtherCtrl.text, '200');
    store.dispose();
  });

  test(
    'persistFacts upserts ndis_plan_budgets JSON not flat budget keys',
    () async {
      final putKeys = <String>[];
      final values = <String, Object?>{};
      when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
        final key = inv.positionalArguments[1] as String;
        final body = inv.positionalArguments[2] as ProfileFactUpsert;
        putKeys.add(key);
        values[key] = body.valueJson;
        return Future.value();
      });

      final store =
          SupportPlanFundingConsentStore(repository: mock)
            ..hasHydrated = true
            ..planManagementType.value = 'ndia';
      store.budgetCoreCtrl.text = '1000';
      store.budgetCbCtrl.text = '500';

      final failed = await store.persistFacts(clientId: 'c1');
      expect(failed, isEmpty);
      expect(putKeys, contains(OnboardingKeys.ndisPlanBudgets));
      expect(putKeys, isNot(contains(OnboardingKeys.budgetCore)));
      final json = values[OnboardingKeys.ndisPlanBudgets]! as Map;
      final budgets = json['budgets'] as List;
      expect(
        budgets.any((b) => b['type'] == 'core' && b['amount_dollars'] == 1000),
        isTrue,
      );
      store.dispose();
    },
  );

  test('persistFacts clears legacy budget keys when saving JSON', () async {
    final putBodies = <String, ProfileFactUpsert>{};
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
      final key = inv.positionalArguments[1] as String;
      putBodies[key] = inv.positionalArguments[2] as ProfileFactUpsert;
      return Future.value();
    });

    final store = SupportPlanFundingConsentStore(repository: mock);
    store.applyProfileBundle(
      const ClientProfileBundle(
        facts: [
          ClientProfileFactOut(
            requirementKey: OnboardingKeys.budgetCore,
            valueJson: 9000,
          ),
        ],
      ),
    );
    store.planManagementType.value = 'ndia';
    store.budgetCoreCtrl.text = '1000';

    final failed = await store.persistFacts(clientId: 'c1');
    expect(failed, isEmpty);
    expect(putBodies[OnboardingKeys.budgetCore]?.clearValue, isTrue);
    store.dispose();
  });

  test('applyProfileBundle hydrates support_plan_specialists JSON', () {
    final store = SupportPlanFundingConsentStore(repository: mock);
    store.applyProfileBundle(
      const ClientProfileBundle(
        facts: [
          ClientProfileFactOut(
            requirementKey: OnboardingKeys.supportPlanSpecialists,
            valueJson: [
              {'type': 'physiotherapist', 'name': 'Bob PT'},
            ],
          ),
        ],
      ),
    );
    expect(store.supportSpecialists, hasLength(1));
    expect(store.supportSpecialists.first.fields.nameCtrl.text, 'Bob PT');
    store.dispose();
  });

  test(
    'persistFacts upserts support_plan_specialists not flat coordinator keys',
    () async {
      final putKeys = <String>[];
      when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
        putKeys.add(inv.positionalArguments[1] as String);
        return Future.value();
      });

      final store =
          SupportPlanFundingConsentStore(repository: mock)
            ..hasHydrated = true
            ..planManagementType.value = 'ndia';
      store.addSupportSpecialist('speech_therapist');
      store.supportSpecialists.first.fields.nameCtrl.text = 'Alex';

      final failed = await store.persistFacts(clientId: 'c1');
      expect(failed, isEmpty);
      expect(putKeys, contains(OnboardingKeys.supportPlanSpecialists));
      expect(putKeys, isNot(contains(OnboardingKeys.supportCoordinatorName)));
      store.dispose();
    },
  );

  test('D10=A save before hydrate does not PUT facts', () async {
    final putKeys = <String>[];
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
      putKeys.add(inv.positionalArguments[1] as String);
      return Future.value();
    });
    when(
      () => mock.patchSupportPlan(any(), any(), any()),
    ).thenAnswer((_) async => _plan());

    final store = SupportPlanFundingConsentStore(repository: mock);
    expect(store.hasHydrated, isFalse);
    final plan = SupportPlanController(
      repository: mock,
      clientId: 'c1',
      planId: 'plan-1',
      fundingConsent: store,
    );
    plan.planId.value = 'plan-1';
    await plan.saveDraft();
    expect(putKeys, isEmpty);
    verify(() => mock.patchSupportPlan('c1', 'plan-1', any())).called(1);
    plan.onClose();
  });

  test('D3=A fact failure skips plan PATCH and reloads', () async {
    var reloads = 0;
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer(
      (_) async =>
          throw const AppFailure(
            code: 'server_error',
            message: 'fact failed',
            presentation: AppFailurePresentation.inline,
          ),
    );
    when(
      () => mock.getClientProfile(any()),
    ).thenAnswer((_) async => const ClientProfileBundle());

    final store =
        SupportPlanFundingConsentStore(repository: mock)
          ..hasHydrated = true
          ..planManagementType.value = 'self_managed'
          ..onReload = () => reloads++;
    final plan = SupportPlanController(
      repository: mock,
      clientId: 'c1',
      planId: 'plan-1',
      fundingConsent: store,
    );
    plan.planId.value = 'plan-1';

    await plan.saveDraft();

    expect(plan.errorMessage.value, isNotNull);
    expect(reloads, greaterThan(0));
    verifyNever(() => mock.patchSupportPlan(any(), any(), any()));
    plan.onClose();
  });

  test('D3=A / D8 plan PATCH failure reloads funding store', () async {
    var reloads = 0;
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(() => mock.patchSupportPlan(any(), any(), any())).thenThrow(
      const AppFailure(
        code: 'server_error',
        message: 'plan failed',
        presentation: AppFailurePresentation.inline,
      ),
    );
    when(
      () => mock.getClientProfile(any()),
    ).thenAnswer((_) async => const ClientProfileBundle());

    final store =
        SupportPlanFundingConsentStore(repository: mock)
          ..hasHydrated = true
          ..planManagementType.value = 'self_managed'
          ..onReload = () => reloads++;
    final plan = SupportPlanController(
      repository: mock,
      clientId: 'c1',
      planId: 'plan-1',
      fundingConsent: store,
    );
    plan.planId.value = 'plan-1';

    await plan.saveDraft();
    expect(plan.errorMessage.value, 'plan failed');
    expect(reloads, greaterThan(0));
    plan.onClose();
  });

  test('D8 discardDrafts reloads funding store', () async {
    var reloads = 0;
    when(
      () => mock.getSupportPlan(any(), any()),
    ).thenAnswer((_) async => _plan());
    when(
      () => mock.getClientProfile(any()),
    ).thenAnswer((_) async => const ClientProfileBundle());

    final store =
        SupportPlanFundingConsentStore(repository: mock)
          ..hasHydrated = true
          ..onReload = () => reloads++;
    final plan = SupportPlanController(
      repository: mock,
      clientId: 'c1',
      planId: 'plan-1',
      fundingConsent: store,
    );

    await plan.discardDrafts();
    expect(reloads, greaterThan(0));
    plan.onClose();
  });

  test(
    'activate with missing SA sets soft warning but still patches',
    () async {
      when(
        () => mock.upsertProfileFact(any(), any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mock.patchSupportPlan(any(), any(), any()),
      ).thenAnswer((_) async => _plan(status: SupportPlanKeys.statusActive));

      final store =
          SupportPlanFundingConsentStore(repository: mock)
            ..hasHydrated = true
            ..planManagementType.value = 'self_managed'
            ..consentAgreementComplete.value = true
            ..serviceAgreementComplete.value = false;
      final plan = SupportPlanController(
        repository: mock,
        clientId: 'c1',
        planId: 'plan-1',
        fundingConsent: store,
      );
      plan.nextReviewAt.value = '2026-09-01';

      await plan.activate();

      expect(plan.status.value, SupportPlanKeys.statusActive);
      expect(plan.activateSoftWarning.value, contains('Service Agreement'));
      verify(() => mock.patchSupportPlan('c1', 'plan-1', any())).called(1);
      plan.onClose();
    },
  );

  test('isBusy is true when fundingConsent.isBusy', () {
    final store = SupportPlanFundingConsentStore(repository: mock);
    final plan = SupportPlanController(
      repository: mock,
      clientId: 'c1',
      fundingConsent: store,
    );
    expect(plan.isBusy, isFalse);
    store.isBusy.value = true;
    expect(plan.isBusy, isTrue);
    plan.onClose();
  });

  test('markConsentComplete uses row uploading not global isBusy', () async {
    final pipeline = _MockDocumentPipeline();
    final uploadGate = Completer<DocumentOut>();
    when(() => mock.getLegalDocumentCurrent(any())).thenAnswer(
      (_) async => const ClientLegalDocumentCurrent(
        id: 'legal-v1',
        title: 'Consent',
        contentMd: '# Consent',
      ),
    );
    when(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) => uploadGate.future);
    when(
      () => mock.acceptClientLegal(any(), any(), any()),
    ).thenAnswer((_) async {});

    final store = SupportPlanFundingConsentStore(
      repository: mock,
      documentPipeline: pipeline,
      pickPdfBytes: () async => (name: 'consent.pdf', bytes: [1, 2, 3]),
    );
    store.consentSignerNameCtrl.text = 'Sam Parent';
    final plan = SupportPlanController(
      repository: mock,
      clientId: 'c1',
      fundingConsent: store,
    );

    final future = store.markConsentComplete(clientId: 'c1');
    await Future<void>.delayed(Duration.zero);
    expect(store.consentUploading.value, isTrue);
    expect(store.isBusy.value, isFalse);
    expect(plan.isBusy, isFalse);

    uploadGate.complete(
      const DocumentOut(
        id: 'doc-1',
        ownerType: 'client',
        ownerId: 'c1',
        filename: 'consent.pdf',
        contentType: 'application/pdf',
        sizeBytes: 3,
        scanStatus: 'clean',
      ),
    );
    expect(await future, isTrue);
    expect(store.consentUploading.value, isFalse);
    expect(store.consentAgreementComplete.value, isTrue);
    plan.onClose();
  });

  test('D7=A _persist no-ops while store.isBusy', () async {
    final store =
        SupportPlanFundingConsentStore(repository: mock)
          ..isBusy.value = true
          ..hasHydrated = true
          ..planManagementType.value = 'self_managed';
    final plan = SupportPlanController(
      repository: mock,
      clientId: 'c1',
      planId: 'plan-1',
      fundingConsent: store,
    );
    await plan.saveDraft();
    verifyNever(() => mock.patchSupportPlan(any(), any(), any()));
    verifyNever(() => mock.upsertProfileFact(any(), any(), any()));
    plan.onClose();
  });

  test(
    'D14=C 409 profile_fact_conflict reloads and skips plan PATCH',
    () async {
      var reloads = 0;
      when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer(
        (_) async =>
            throw const AppFailure(
              code: 'profile_fact_conflict',
              message: 'stale',
              statusCode: 409,
              presentation: AppFailurePresentation.inline,
            ),
      );
      when(
        () => mock.getClientProfile(any()),
      ).thenAnswer((_) async => const ClientProfileBundle());

      final store =
          SupportPlanFundingConsentStore(repository: mock)
            ..hasHydrated = true
            ..planManagementType.value = 'self_managed'
            ..onReload = () => reloads++;
      final plan = SupportPlanController(
        repository: mock,
        clientId: 'c1',
        planId: 'plan-1',
        fundingConsent: store,
      );

      await plan.saveDraft();

      expect(
        plan.errorMessage.value,
        SupportPlanFundingConsentStore.conflictMessage,
      );
      expect(reloads, greaterThan(0));
      verifyNever(() => mock.patchSupportPlan(any(), any(), any()));
      plan.onClose();
    },
  );

  test('persistFacts sends expectedUpdatedAt from hydrate snapshot', () async {
    final captured = <String, ProfileFactUpsert>{};
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
      final key = inv.positionalArguments[1] as String;
      captured[key] = inv.positionalArguments[2] as ProfileFactUpsert;
      return Future.value();
    });

    final stamp = DateTime.utc(2026, 8, 1, 12);
    final store = SupportPlanFundingConsentStore(repository: mock);
    store.applyProfileBundle(
      ClientProfileBundle(
        facts: [
          ClientProfileFactOut(
            requirementKey: OnboardingKeys.planManagementType,
            valueJson: 'ndia',
            updatedAt: stamp,
          ),
        ],
      ),
    );
    store.planManagementType.value = 'self_managed';

    await store.persistFacts(clientId: 'c1');
    expect(
      captured[OnboardingKeys.planManagementType]?.expectedUpdatedAt,
      stamp,
    );
    store.dispose();
  });

  test(
    'applyProfileBundle hydrates legacy funding_not_to_exceed into Other',
    () {
      final store = SupportPlanFundingConsentStore(repository: mock);
      store.applyProfileBundle(
        const ClientProfileBundle(
          facts: [
            ClientProfileFactOut(
              requirementKey: OnboardingKeys.fundingNotToExceed,
              valueJson: 5000,
            ),
          ],
        ),
      );
      expect(store.supportPlanOtherCtrl.text, '5000');
      store.dispose();
    },
  );

  test('applyProfileBundle prefers support_plan_other over legacy Other', () {
    final store = SupportPlanFundingConsentStore(repository: mock);
    store.applyProfileBundle(
      const ClientProfileBundle(
        facts: [
          ClientProfileFactOut(
            requirementKey: OnboardingKeys.supportPlanOther,
            valueJson: 'Custom note',
          ),
          ClientProfileFactOut(
            requirementKey: OnboardingKeys.fundingNotToExceed,
            valueJson: 5000,
          ),
        ],
      ),
    );
    expect(store.supportPlanOtherCtrl.text, 'Custom note');
    store.dispose();
  });

  test('persistFacts upserts NDIS and support_plan_other', () async {
    final putKeys = <String>[];
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
      putKeys.add(inv.positionalArguments[1] as String);
      return Future.value();
    });

    final store = SupportPlanFundingConsentStore(repository: mock);
    store.hasHydrated = true;
    store.ndisCtrl.text = '431234567';
    store.supportPlanOtherCtrl.text = 'Notes';
    store.planManagementType.value = 'self_managed';

    final failed = await store.persistFacts(clientId: 'c1');
    expect(failed, isEmpty);
    expect(putKeys, contains(OnboardingKeys.ndis));
    expect(putKeys, contains(OnboardingKeys.supportPlanOther));
    store.dispose();
  });

  test('persistFacts sets ndisFieldError on ndis_number_in_use', () async {
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
      if (inv.positionalArguments[1] == OnboardingKeys.ndis) {
        return Future<void>.error(
          const AppFailure(
            code: 'ndis_number_in_use',
            message: 'This NDIS number is already used by another client.',
            presentation: AppFailurePresentation.inline,
          ),
        );
      }
      return Future.value();
    });

    final store = SupportPlanFundingConsentStore(repository: mock);
    store.hasHydrated = true;
    store.ndisCtrl.text = '431234567';
    store.planManagementType.value = 'self_managed';

    final failed = await store.persistFacts(clientId: 'c1');
    expect(failed, contains('NDIS number'));
    expect(store.ndisFieldError.value, contains('already used'));
    store.dispose();
  });

  test('pickNdisPlanPdf holds locally and does not set isBusy', () async {
    final store = SupportPlanFundingConsentStore(
      repository: mock,
      documentPipeline: _MockDocumentPipeline(),
      pickPdfBytes: () async => (name: 'ndia.pdf', bytes: [1, 2, 3]),
    );
    store.applyProfileBundle(const ClientProfileBundle(facts: []));

    await store.pickNdisPlanPdf();

    expect(store.ndisPdfPending.value?.name, 'ndia.pdf');
    expect(store.ndisPdfOnFile.value, isFalse);
    expect(store.isBusy.value, isFalse);
    verifyNever(() => mock.upsertProfileFact(any(), any(), any()));
    store.dispose();
  });

  test('persistFacts uploads pending NDIA PDF with documentId', () async {
    final pipeline = _MockDocumentPipeline();
    when(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer(
      (_) async => const DocumentOut(
        id: 'doc-ndis-1',
        ownerType: 'client',
        ownerId: 'c1',
        filename: 'ndia.pdf',
        contentType: 'application/pdf',
        sizeBytes: 3,
        scanStatus: 'clean',
      ),
    );
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async => const ClientProfileFactOut(requirementKey: 'x'));

    final store = SupportPlanFundingConsentStore(
      repository: mock,
      documentPipeline: pipeline,
      pickPdfBytes: () async => (name: 'ndia.pdf', bytes: [1, 2, 3]),
    );
    store.applyProfileBundle(const ClientProfileBundle(facts: []));
    store.ndisCtrl.text = '431234567';
    await store.pickNdisPlanPdf();

    final failed = await store.persistFacts(clientId: 'c1');
    expect(failed, isEmpty);
    expect(store.ndisPdfPending.value, isNull);
    expect(store.ndisPdfOnFile.value, isTrue);
    expect(store.isBusy.value, isFalse);
    verify(
      () => mock.upsertProfileFact(
        'c1',
        OnboardingKeys.ndis,
        any(
          that: predicate<ProfileFactUpsert>(
            (u) => u.documentId == 'doc-ndis-1' && u.valueJson == '431234567',
          ),
        ),
      ),
    ).called(1);
    store.dispose();
  });

  testWidgets('Support Plan section shows NDIS, plan management and NDIA PDF', (
    tester,
  ) async {
    final store = SupportPlanFundingConsentStore(repository: mock);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SupportPlanFundingSection(store: store, clientId: 'c1'),
          ),
        ),
      ),
    );
    expect(find.text('Support Plan'), findsOneWidget);
    expect(find.textContaining('NDIS number'), findsOneWidget);
    expect(find.textContaining('Plan management'), findsOneWidget);
    expect(find.textContaining('NDIA plan PDF'), findsWidgets);
    expect(find.textContaining('Preferred claiming'), findsOneWidget);
    expect(find.text('Support Coordinator'), findsOneWidget);
    expect(find.text('SC name'), findsOneWidget);
    expect(find.text('Add support specialist'), findsOneWidget);
    store.dispose();
  });

  testWidgets('funding add specialist sheet excludes support coordinator', (
    tester,
  ) async {
    final store = SupportPlanFundingConsentStore(repository: mock);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SupportPlanFundingSection(store: store, clientId: 'c1'),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Add support specialist'));
    await tester.tap(find.text('Add support specialist'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Support coordinator'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Speech therapist'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Other specialist'), findsOneWidget);
    store.dispose();
  });

  testWidgets('Consent section shows legal status and share flags', (
    tester,
  ) async {
    final store = SupportPlanFundingConsentStore(repository: mock);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SupportPlanConsentSection(store: store, clientId: 'c1'),
          ),
        ),
      ),
    );
    expect(find.text('Consent & agreements'), findsOneWidget);
    expect(find.textContaining('Consent agreement'), findsWidgets);
    expect(find.textContaining('Service agreement'), findsWidgets);
    expect(find.textContaining('Information share'), findsOneWidget);
    expect(find.textContaining('Specific supports'), findsOneWidget);
    store.dispose();
  });
}
