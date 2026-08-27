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
    when(() => mock.upsertProfileFact(any(), any(), any())).thenThrow(
      const AppFailure(
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
}
