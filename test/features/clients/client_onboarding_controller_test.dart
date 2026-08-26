import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _FakeClientCreateRequest extends Fake implements ClientCreateRequest {}

class _FakeClientUpdateRequest extends Fake implements ClientUpdateRequest {}

class _FakeProfileFactUpsert extends Fake implements ProfileFactUpsert {}

class _FakeClientSiteWriteRequest extends Fake
    implements ClientSiteWriteRequest {}

class _FakeClientContactWriteRequest extends Fake
    implements ClientContactWriteRequest {}

class _FakeGeocodeRequest extends Fake implements GeocodeRequest {}

final _now = DateTime.utc(2026, 8, 26, 9);

final _fakeClient = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Sam Parent',
  status: 'active',
  metadata: const {'onboarding_incomplete': true},
  createdAt: _now,
  updatedAt: _now,
  email: 'sam@example.com',
  phone: '+61411111111',
  clientTypeId: 'type-patient',
  dob: '2015-01-01',
);

final _patientType = ClientTypeOut(
  id: 'type-patient',
  code: 'patient',
  name: 'Patient',
  isActive: true,
  sortOrder: 1,
);

void main() {
  late _MockClientsRepository mock;
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
    when(() => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')))
        .thenAnswer((_) async => <FormTemplateSummary>[]);
    when(() => mock.listClientTypes()).thenAnswer((_) async => [_patientType]);
    c = ClientOnboardingController(repository: mock);
  });

  tearDown(() {
    c.dispose();
  });

  test('cannot leave Identity without dob and ndis', () async {
    c.fullName.text = 'Sam';
    c.phone.text = '+61411111111';
    expect(await c.submitIdentity(), isFalse);
    expect(c.errorMessage.value, contains('DOB'));
    expect(c.step.value, 0);
  });

  test('cannot leave Identity without ndis when dob set', () async {
    c.fullName.text = 'Sam';
    c.phone.text = '+61411111111';
    c.dob.value = DateTime(1990, 1, 1);
    expect(await c.submitIdentity(), isFalse);
    expect(c.errorMessage.value, contains('NDIS'));
    expect(c.ndisFieldError.value, isNotNull);
  });

  test('submitIdentity sets onboarding_incomplete and advances', () async {
    ClientCreateRequest? captured;
    when(() => mock.createClient(any())).thenAnswer((inv) async {
      captured = inv.positionalArguments.first as ClientCreateRequest;
      return _fakeClient;
    });
    when(() => mock.upsertProfileFact(any(), any(), any()))
        .thenAnswer((_) async {});

    c.fullName.text = 'Sam Parent';
    c.phone.text = '+61411111111';
    c.dob.value = DateTime(1990, 5, 1);
    c.ndisCtrl.text = '430118201';

    expect(await c.submitIdentity(), isTrue);
    expect(c.step.value, 1);
    expect(captured?.metadata?['onboarding_incomplete'], isTrue);
    verify(
      () => mock.upsertProfileFact('client-1', OnboardingKeys.ndis, any()),
    ).called(1);
  });

  test('maps 409 ndis_number_in_use to field error', () async {
    when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
    when(() => mock.upsertProfileFact(any(), OnboardingKeys.ndis, any()))
        .thenThrow(
      const AppFailure(
        code: 'ndis_number_in_use',
        message: 'This NDIS number is already used by another client.',
        presentation: AppFailurePresentation.inline,
        statusCode: 409,
      ),
    );

    c.fullName.text = 'Sam';
    c.phone.text = '+61411111111';
    c.dob.value = DateTime(1990, 1, 1);
    c.ndisCtrl.text = '430118201';

    expect(await c.submitIdentity(), isFalse);
    expect(c.ndisFieldError.value, contains('NDIS'));
    expect(c.step.value, 0);
  });

  test('representative step requires child_representative when under 18', () {
    c.dob.value = DateTime(2015, 1, 1);
    expect(c.requiresChildRepresentative, isTrue);
    expect(c.nomineeOptional, isFalse);
  });

  test('representative step optional nominee when adult', () {
    c.dob.value = DateTime(2000, 1, 1);
    expect(c.requiresChildRepresentative, isFalse);
    expect(c.nomineeOptional, isTrue);
  });

  test('submitFunding blocks plan_managed without manager fields', () async {
    c.client.value = _fakeClient;
    c.step.value = 5;
    c.planManagementType.value = 'plan_managed';
    expect(await c.submitFunding(), isFalse);
    expect(c.errorMessage.value, contains('Plan manager'));
  });

  test('submitFunding accepts self_managed', () async {
    when(() => mock.upsertProfileFact(any(), any(), any()))
        .thenAnswer((_) async {});
    c.client.value = _fakeClient;
    c.step.value = 5;
    c.planManagementType.value = 'self_managed';
    expect(await c.submitFunding(), isTrue);
    expect(c.step.value, 6);
  });

  test('finishOnboarding soft gate warns then clears incomplete flag', () async {
    var softGateCalled = false;
    ClientUpdateRequest? patch;
    when(() => mock.getClient('client-1')).thenAnswer((_) async => _fakeClient);
    when(() => mock.patchClient(any(), any())).thenAnswer((inv) async {
      patch = inv.positionalArguments[1] as ClientUpdateRequest;
      return ClientOut(
        id: _fakeClient.id,
        tenantId: _fakeClient.tenantId,
        fullName: _fakeClient.fullName,
        status: _fakeClient.status,
        metadata: patch?.metadata ?? {},
        createdAt: _now,
        updatedAt: _now,
      );
    });

    String? finishedId;
    c = ClientOnboardingController(
      repository: mock,
      softGateConfirm: (missing) async {
        softGateCalled = true;
        expect(missing, containsAll(['Consent', 'Service Agreement']));
        return true;
      },
      onFinished: (id) => finishedId = id,
    );
    c.client.value = _fakeClient;
    c.step.value = 6;

    expect(await c.finishOnboarding(), isTrue);
    expect(softGateCalled, isTrue);
    expect(patch?.metadata?['onboarding_incomplete'], isFalse);
    expect(finishedId, 'client-1');
  });

  test('finishOnboarding aborts when soft gate declined', () async {
    c = ClientOnboardingController(
      repository: mock,
      softGateConfirm: (_) async => false,
    );
    c.client.value = _fakeClient;
    c.step.value = 6;
    expect(await c.finishOnboarding(), isFalse);
    verifyNever(() => mock.patchClient(any(), any()));
  });

  test('finishOnboarding re-fetches client so photo_document_id is not wiped',
      () async {
    // Local client is stale: only onboarding_incomplete (simulates post-_persistPhoto
    // before metadata refresh).
    when(() => mock.getClient('client-1')).thenAnswer(
      (_) async => ClientOut(
        id: 'client-1',
        tenantId: 'tenant-1',
        fullName: 'Sam Parent',
        status: 'active',
        metadata: const {
          'onboarding_incomplete': true,
          'photo_document_id': 'doc-photo-1',
        },
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    ClientUpdateRequest? patch;
    when(() => mock.patchClient(any(), any())).thenAnswer((inv) async {
      patch = inv.positionalArguments[1] as ClientUpdateRequest;
      return ClientOut(
        id: 'client-1',
        tenantId: 'tenant-1',
        fullName: 'Sam Parent',
        status: 'active',
        metadata: patch?.metadata ?? {},
        createdAt: _now,
        updatedAt: _now,
      );
    });

    c = ClientOnboardingController(
      repository: mock,
      softGateConfirm: (_) async => true,
      onFinished: (_) {},
    );
    c.client.value = _fakeClient;
    c.step.value = 6;

    expect(await c.finishOnboarding(), isTrue);
    verify(() => mock.getClient('client-1')).called(1);
    expect(patch?.metadata?['onboarding_incomplete'], isFalse);
    expect(patch?.metadata?['photo_document_id'], 'doc-photo-1');
  });

  test('finishOnboarding does not patch when getClient fails', () async {
    c = ClientOnboardingController(
      repository: mock,
      softGateConfirm: (_) async => true,
      onFinished: (_) {},
    );
    c.client.value = _fakeClient;
    c.step.value = 6;

    when(() => mock.getClient('client-1')).thenThrow(
      const AppFailure(
        code: 'network',
        message: 'Failed to load client',
        presentation: AppFailurePresentation.inline,
      ),
    );

    expect(await c.finishOnboarding(), isFalse);
    expect(c.errorMessage.value, 'Failed to load client');
    verifyNever(() => mock.patchClient(any(), any()));
  });

  test('finishOnboarding maps unexpected errors to a generic message',
      () async {
    c = ClientOnboardingController(
      repository: mock,
      softGateConfirm: (_) async => true,
      onFinished: (_) {},
    );
    c.client.value = _fakeClient;
    c.step.value = 6;

    when(() => mock.getClient('client-1')).thenThrow(StateError('secret-stack'));

    expect(await c.finishOnboarding(), isFalse);
    expect(c.errorMessage.value, isNot(contains('secret-stack')));
    expect(c.errorMessage.value, isNot(contains('StateError')));
    expect(
      c.errorMessage.value,
      'Something went wrong. Please try again.',
    );
    verifyNever(() => mock.patchClient(any(), any()));
  });

  test('lookupSiteAddress rejects low confidence like ClientsController',
      () async {
    when(() => mock.geocode(any())).thenAnswer(
      (_) async => const GeocodeResponse(
        latitude: -33.86,
        longitude: 151.2,
        formattedAddress: 'Somewhere vague',
        confidence: 'low',
      ),
    );
    c.siteAddressCtrl.text = '1 Test St';
    c.siteCityCtrl.text = 'Sydney';

    await c.lookupSiteAddress();

    expect(c.siteLatCtrl.text, isEmpty);
    expect(c.siteLngCtrl.text, isEmpty);
    expect(c.geocodeFormattedAddress.value, isNull);
    expect(c.addressConfirmed.value, isFalse);
    expect(c.errorMessage.value, contains('low confidence'));
  });

  test('submitContacts requires emergency contact', () async {
    c.client.value = _fakeClient;
    c.step.value = 3;
    expect(await c.submitContacts(), isFalse);
    expect(c.errorMessage.value, contains('emergency'));
  });

  test('submitRepresentative blocks under-18 without child rep', () async {
    c.client.value = _fakeClient;
    c.dob.value = DateTime(2015, 1, 1);
    c.step.value = 4;
    expect(await c.submitRepresentative(), isFalse);
    expect(c.errorMessage.value, contains('child representative'));
  });

  test('submitRepresentative allows adult to skip nominee', () async {
    c.client.value = _fakeClient;
    c.dob.value = DateTime(2000, 1, 1);
    c.step.value = 4;
    expect(await c.submitRepresentative(), isTrue);
    expect(c.nomineeSkipped.value, isTrue);
    expect(c.step.value, 5);
  });
}
