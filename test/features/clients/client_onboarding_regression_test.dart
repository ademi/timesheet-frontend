import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeClientCreateRequest extends Fake implements ClientCreateRequest {}

class _FakeClientUpdateRequest extends Fake implements ClientUpdateRequest {}

class _FakeProfileFactUpsert extends Fake implements ProfileFactUpsert {}

class _FakeClientSiteWriteRequest extends Fake
    implements ClientSiteWriteRequest {}

class _FakeClientContactWriteRequest extends Fake
    implements ClientContactWriteRequest {}

class _FakeGeocodeRequest extends Fake implements GeocodeRequest {}

final _now = DateTime.utc(2026, 8, 30, 12);

final _fakeClient = ClientOut(
  id: 'client-reg-1',
  tenantId: 'tenant-1',
  fullName: 'Reg Client',
  status: 'active',
  metadata: const {'onboarding_incomplete': true},
  createdAt: _now,
  updatedAt: _now,
  email: 'reg@example.com',
  phone: '+61411111111',
  clientTypeId: 'type-patient',
  dob: '1990-01-01',
);

final _patientType = ClientTypeOut(
  id: 'type-patient',
  code: 'patient',
  name: 'Patient',
  isActive: true,
  sortOrder: 1,
);

/// Phase G regression: skip contacts → Support Plan → finish path.
void main() {
  late _MockClientsRepository mock;
  late _MockSessionService session;
  late ClientOnboardingController c;

  setUpAll(() {
    registerFallbackValue(_FakeClientCreateRequest());
    registerFallbackValue(_FakeClientUpdateRequest());
    registerFallbackValue(_FakeProfileFactUpsert());
    registerFallbackValue(_FakeClientSiteWriteRequest());
    registerFallbackValue(_FakeClientContactWriteRequest());
    registerFallbackValue(_FakeGeocodeRequest());
  });

  setUp(() {
    mock = _MockClientsRepository();
    session = _MockSessionService();
    when(() => mock.listClientTypes()).thenAnswer((_) async => [_patientType]);
    when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
    when(() => mock.patchClient(any(), any())).thenAnswer((_) async => _fakeClient);
    when(() => mock.upsertProfileFact(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => mock.getClient(any())).thenAnswer((_) async => _fakeClient);

    c = ClientOnboardingController(
      repository: mock,
      session: session,
      softGateConfirm: (_) async => true,
      onFinished: (_) {},
    );
  });

  tearDown(() => c.dispose());

  test('skip contacts path reaches Support Plan and finishes', () async {
    c.fullName.text = 'Reg Client';
    c.email.text = 'reg@example.com';
    c.phone.text = '+61411111111';
    c.dob.value = DateTime(1990, 1, 1);

    expect(await c.submitIdentity(), isTrue);
    c.primarySiteSaved.value = true;
    expect(await c.submitAddress(), isTrue);
    expect(await c.submitPreferences(), isTrue);

    c.step.value = 3;
    expect(await c.submitContacts(), isTrue);
    expect(c.contactsCreated, isEmpty);

    c.dob.value = DateTime(1990, 1, 1);
    c.step.value = 4;
    expect(await c.submitRepresentative(), isTrue);

    c.ndisCtrl.text = '431234567';
    c.planManagementType.value = 'self_managed';
    c.step.value = 5;
    expect(await c.submitSupportPlan(), isTrue);
    expect(c.step.value, 6);

    c.consentComplete.value = true;
    c.serviceAgreementComplete.value = true;
    expect(await c.finishOnboarding(), isTrue);
    verify(
      () => mock.upsertProfileFact('client-reg-1', OnboardingKeys.ndis, any()),
    ).called(1);
  });

  test('resume hydrates Support Plan from profile facts', () {
    c.hydrateSupportPlanFromFacts([
      const ClientProfileFactOut(
        requirementKey: OnboardingKeys.ndis,
        valueJson: '431234567',
      ),
      const ClientProfileFactOut(
        requirementKey: OnboardingKeys.planManagementType,
        valueJson: 'ndia',
      ),
      const ClientProfileFactOut(
        requirementKey: OnboardingKeys.fundingNotToExceed,
        valueJson: '999',
      ),
    ]);
    expect(c.ndisCtrl.text, '431234567');
    expect(c.planManagementType.value, 'ndia');
    expect(c.supportPlanOtherCtrl.text, '999');
  });

  test('NDIS collision stays on Support Plan step', () async {
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
      if (inv.positionalArguments[1] == OnboardingKeys.ndis) {
        throw const AppFailure(
          code: 'ndis_number_in_use',
          message: 'This NDIS number is already used by another client.',
          presentation: AppFailurePresentation.inline,
        );
      }
      return Future.value();
    });
    c.client.value = _fakeClient;
    c.step.value = 5;
    c.ndisCtrl.text = '431234567';
    c.planManagementType.value = 'self_managed';

    expect(await c.submitSupportPlan(), isFalse);
    expect(c.ndisFieldError.value, isNotNull);
    expect(c.step.value, 5);
  });
}
