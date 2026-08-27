import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _FakeClientCreateRequest extends Fake implements ClientCreateRequest {}

class _FakeClientUpdateRequest extends Fake implements ClientUpdateRequest {}

class _FakeProfileFactUpsert extends Fake implements ProfileFactUpsert {}

class _FakeClientSiteWriteRequest extends Fake
    implements ClientSiteWriteRequest {}

class _FakeClientContactWriteRequest extends Fake
    implements ClientContactWriteRequest {}

class _FakeClientLegalAcceptRequest extends Fake
    implements ClientLegalAcceptRequest {}

class _FakeGeocodeRequest extends Fake implements GeocodeRequest {}

class _FakeUploadUrlRequest extends Fake implements UploadUrlRequest {}

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
  late _MockSessionService session;
  late ClientOnboardingController c;

  ClientOnboardingController _buildController({
    Future<bool> Function(List<String> missing)? softGateConfirm,
    void Function(String clientId)? onFinished,
    DocumentPipeline? documentPipeline,
    SessionService? sessionOverride,
    Future<({String name, List<int> bytes})?> Function()? pickPdfBytes,
  }) {
    return ClientOnboardingController(
      repository: mock,
      session: sessionOverride ?? session,
      documentPipeline: documentPipeline,
      pickPdfBytes: pickPdfBytes,
      softGateConfirm: softGateConfirm,
      onFinished: onFinished,
    );
  }

  setUpAll(() {
    registerFallbackValue(_FakeClientCreateRequest());
    registerFallbackValue(_FakeClientUpdateRequest());
    registerFallbackValue(_FakeProfileFactUpsert());
    registerFallbackValue(_FakeClientSiteWriteRequest());
    registerFallbackValue(_FakeClientContactWriteRequest());
    registerFallbackValue(_FakeClientLegalAcceptRequest());
    registerFallbackValue(_FakeGeocodeRequest());
    registerFallbackValue(_FakeUploadUrlRequest());
  });

  setUp(() {
    mock = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')))
        .thenAnswer((_) async => <FormTemplateSummary>[]);
    when(() => mock.listClientTypes()).thenAnswer((_) async => [_patientType]);
    c = _buildController();
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
    c.dispose();
    c = _buildController(
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
    c.dispose();
    c = _buildController(
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

    c.dispose();
    c = _buildController(
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
    c.dispose();
    c = _buildController(
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
    c.dispose();
    c = _buildController(
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

  test('markConsentComplete fetches legal doc with patient.consent_agreement',
      () async {
    final pipeline = _MockDocumentPipeline();
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
    when(() => mock.getLegalDocumentCurrent(any())).thenAnswer(
      (_) async => const ClientLegalDocumentCurrent(
        id: 'legal-v1',
        title: 'Consent',
        contentMd: '# Consent',
      ),
    );
    when(() => mock.acceptClientLegal(any(), any(), any()))
        .thenAnswer((_) async {});

    c.dispose();
    c = _buildController(
      documentPipeline: pipeline,
      pickPdfBytes: () async => (name: 'consent.pdf', bytes: [1, 2, 3]),
    );
    c.client.value = _fakeClient;
    c.consentSignerNameCtrl.text = 'Sam Parent';

    expect(await c.markConsentComplete(), isTrue);
    expect(c.consentComplete.value, isTrue);
    verify(
      () => mock.getLegalDocumentCurrent(OnboardingKeys.consentAgreementDocKey),
    ).called(1);
    verify(
      () => mock.acceptClientLegal(
        'client-1',
        OnboardingKeys.consentAgreement,
        any(),
      ),
    ).called(1);
  });

  test('markConsentComplete shows friendly message when legal doc missing',
      () async {
    final pipeline = _MockDocumentPipeline();
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
    when(() => mock.getLegalDocumentCurrent(any())).thenThrow(
      const AppFailure(
        code: 'legal_document_unavailable',
        message: 'This legal document is not available yet.',
        presentation: AppFailurePresentation.inline,
        statusCode: 404,
      ),
    );

    c.dispose();
    c = _buildController(
      documentPipeline: pipeline,
      pickPdfBytes: () async => (name: 'consent.pdf', bytes: [1, 2, 3]),
    );
    c.client.value = _fakeClient;
    c.consentSignerNameCtrl.text = 'Sam Parent';

    expect(await c.markConsentComplete(), isFalse);
    expect(c.consentComplete.value, isFalse);
    expect(
      c.errorMessage.value,
      'Consent legal text is not published for this tenant — contact support.',
    );
    verifyNever(() => mock.acceptClientLegal(any(), any(), any()));
  });

  test('upload fails closed without documents.upload / clients.docs.manage',
      () async {
    final deniedSession = _MockSessionService();
    final pipeline = _MockDocumentPipeline();
    when(() => deniedSession.hasPermission(any())).thenReturn(false);

    c.dispose();
    c = _buildController(
      documentPipeline: pipeline,
      sessionOverride: deniedSession,
    );
    c.pendingPhoto.value = const PickedProfilePhoto(
      name: 'a.jpg',
      contentType: 'image/jpeg',
      bytes: [1, 2, 3],
    );
    when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
    when(() => mock.upsertProfileFact(any(), any(), any()))
        .thenAnswer((_) async {});

    c.fullName.text = 'Sam';
    c.phone.text = '+61411111111';
    c.dob.value = DateTime(1990, 1, 1);
    c.ndisCtrl.text = '430118201';

    expect(await c.submitIdentity(), isFalse);
    expect(c.errorMessage.value, contains('documents.upload'));
    verifyNever(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    );
  });

  test('hydrateFromClient prefills Identity, sets client, step 0', () {
    c.step.value = 4;
    c.hydrateFromClient(_fakeClient);

    expect(c.client.value?.id, 'client-1');
    expect(c.fullName.text, 'Sam Parent');
    expect(c.email.text, 'sam@example.com');
    expect(c.phone.text, '+61411111111');
    expect(c.dob.value, DateTime(2015, 1, 1));
    expect(c.step.value, 0);
  });

  test('submitIdentity after hydrate patches instead of creates', () async {
    when(() => mock.patchClient(any(), any())).thenAnswer((_) async => _fakeClient);
    when(() => mock.upsertProfileFact(any(), any(), any()))
        .thenAnswer((_) async {});

    c.hydrateFromClient(_fakeClient);
    c.dob.value = DateTime(1990, 5, 1);
    c.ndisCtrl.text = '430118201';

    expect(await c.submitIdentity(), isTrue);
    verify(() => mock.patchClient('client-1', any())).called(1);
    verifyNever(() => mock.createClient(any()));
  });

  test('onPlanStartPicked defaults end to start + 1 year when end is null', () {
    final start = DateTime(2026, 3, 15);
    c.onPlanStartPicked(start);
    expect(c.planStartDate.value, start);
    expect(c.planEndDate.value, DateTime(2027, 3, 15));
  });

  test('onPlanStartPicked does not overwrite an existing plan end', () {
    final existingEnd = DateTime(2026, 12, 1);
    c.planEndDate.value = existingEnd;
    c.onPlanStartPicked(DateTime(2026, 3, 15));
    expect(c.planEndDate.value, existingEnd);
  });
}
