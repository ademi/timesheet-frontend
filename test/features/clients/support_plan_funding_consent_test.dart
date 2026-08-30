import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockClientsRepository extends Mock implements ClientsRepository {}

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
    expect(
      store.validateFunding(requirePlanType: false),
      contains('claiming'),
    );
    store.dispose();
  });

  test('D6=B save draft allows unset plan type; activate requires it', () {
    final store = SupportPlanFundingConsentStore(repository: mock);
    store.planManagementType.value = null;
    expect(store.validateFunding(requirePlanType: false), isNull);
    expect(store.validateFunding(requirePlanType: true), isNotNull);
    store.dispose();
  });

  test('D5=A persistFacts upserts owned keys including false booleans',
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
  });

  test('D10=A save before hydrate does not PUT facts', () async {
    final putKeys = <String>[];
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
      putKeys.add(inv.positionalArguments[1] as String);
      return Future.value();
    });
    when(() => mock.patchSupportPlan(any(), any(), any()))
        .thenAnswer((_) async => _plan());

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
      (_) async => throw const AppFailure(
        code: 'server_error',
        message: 'fact failed',
        presentation: AppFailurePresentation.inline,
      ),
    );
    when(() => mock.getClientProfile(any())).thenAnswer(
      (_) async => const ClientProfileBundle(),
    );

    final store = SupportPlanFundingConsentStore(repository: mock)
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
    when(() => mock.upsertProfileFact(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => mock.patchSupportPlan(any(), any(), any())).thenThrow(
      const AppFailure(
        code: 'server_error',
        message: 'plan failed',
        presentation: AppFailurePresentation.inline,
      ),
    );
    when(() => mock.getClientProfile(any())).thenAnswer(
      (_) async => const ClientProfileBundle(),
    );

    final store = SupportPlanFundingConsentStore(repository: mock)
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
    when(() => mock.getSupportPlan(any(), any()))
        .thenAnswer((_) async => _plan());
    when(() => mock.getClientProfile(any())).thenAnswer(
      (_) async => const ClientProfileBundle(),
    );

    final store = SupportPlanFundingConsentStore(repository: mock)
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

  test('activate with missing SA sets soft warning but still patches', () async {
    when(() => mock.upsertProfileFact(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => mock.patchSupportPlan(any(), any(), any())).thenAnswer(
      (_) async => _plan(status: SupportPlanKeys.statusActive),
    );

    final store = SupportPlanFundingConsentStore(repository: mock)
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
  });

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

  test('D7=A _persist no-ops while store.isBusy', () async {
    final store = SupportPlanFundingConsentStore(repository: mock)
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

  test('D14=C 409 profile_fact_conflict reloads and skips plan PATCH', () async {
    var reloads = 0;
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer(
      (_) async => throw const AppFailure(
        code: 'profile_fact_conflict',
        message: 'stale',
        statusCode: 409,
        presentation: AppFailurePresentation.inline,
      ),
    );
    when(() => mock.getClientProfile(any())).thenAnswer(
      (_) async => const ClientProfileBundle(),
    );

    final store = SupportPlanFundingConsentStore(repository: mock)
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
  });

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

  test('applyProfileBundle hydrates legacy funding_not_to_exceed into Other',
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
  });

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

  testWidgets('Support Plan section shows NDIS, plan management and NDIA PDF',
      (tester) async {
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
    store.dispose();
  });

  testWidgets('Consent section shows legal status and share flags',
      (tester) async {
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
    expect(find.textContaining('Consent agreement'), findsOneWidget);
    expect(find.textContaining('Service agreement'), findsOneWidget);
    expect(find.textContaining('Information share'), findsOneWidget);
    expect(find.textContaining('Specific supports'), findsOneWidget);
    store.dispose();
  });
}
