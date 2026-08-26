import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

final _now = DateTime.utc(2026, 8, 26, 9);

final _adultClient = ClientOut(
  id: 'client-adult-1',
  tenantId: 'tenant-1',
  fullName: 'Alex Adult',
  status: 'active',
  metadata: const {'onboarding_incomplete': true},
  createdAt: _now,
  updatedAt: _now,
  email: 'alex@example.com',
  phone: '+61422222222',
  clientTypeId: 'type-patient',
  dob: '1990-05-15',
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
  late List<ClientCreateRequest> createCalls;
  late List<ClientUpdateRequest> patchCalls;
  late List<(String clientId, String key, ProfileFactUpsert body)> factUpserts;
  late List<ClientSiteWriteRequest> siteCreates;
  late List<ClientContactWriteRequest> contactCreates;
  late String? finishedId;

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
    when(() => session.hasPermission(any())).thenReturn(true);
    createCalls = [];
    patchCalls = [];
    factUpserts = [];
    siteCreates = [];
    contactCreates = [];
    finishedId = null;

    when(() => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')))
        .thenAnswer((_) async => <FormTemplateSummary>[]);
    when(() => mock.listClientTypes()).thenAnswer((_) async => [_patientType]);

    when(() => mock.createClient(any())).thenAnswer((inv) async {
      final req = inv.positionalArguments.first as ClientCreateRequest;
      createCalls.add(req);
      return _adultClient;
    });

    when(() => mock.upsertProfileFact(any(), any(), any()))
        .thenAnswer((inv) async {
      factUpserts.add((
        inv.positionalArguments[0] as String,
        inv.positionalArguments[1] as String,
        inv.positionalArguments[2] as ProfileFactUpsert,
      ));
    });

    when(() => mock.geocode(any())).thenAnswer(
      (_) async => const GeocodeResponse(
        latitude: -33.8688,
        longitude: 151.2093,
        formattedAddress: '1 George St, Sydney NSW 2000',
      ),
    );

    when(() => mock.createSite(any(), any())).thenAnswer((inv) async {
      final body = inv.positionalArguments[1] as ClientSiteWriteRequest;
      siteCreates.add(body);
      return ClientSiteOut(
        id: 'site-1',
        tenantId: 'tenant-1',
        clientId: 'client-adult-1',
        name: body.name,
        addressLine1: body.addressLine1,
        city: body.city,
        state: body.state,
        country: body.country,
        postalCode: body.postalCode,
        latitude: body.latitude,
        longitude: body.longitude,
        geofenceRadiusM: body.geofenceRadiusM,
        isPrimary: body.isPrimary,
        accessNotes: body.accessNotes,
        createdAt: _now,
        updatedAt: _now,
      );
    });

    when(() => mock.createContact(any(), any())).thenAnswer((inv) async {
      final body = inv.positionalArguments[1] as ClientContactWriteRequest;
      contactCreates.add(body);
      return ClientContactOut(
        id: 'contact-${contactCreates.length}',
        tenantId: 'tenant-1',
        clientId: 'client-adult-1',
        name: body.name,
        email: body.email,
        phone: body.phone,
        relationship: body.relationship,
        isPrimary: body.isPrimary,
        notifyVisitComplete: body.notifyVisitComplete,
      );
    });

    when(() => mock.getClient(any())).thenAnswer((_) async => c.client.value!);

    when(() => mock.patchClient(any(), any())).thenAnswer((inv) async {
      final patch = inv.positionalArguments[1] as ClientUpdateRequest;
      patchCalls.add(patch);
      return ClientOut(
        id: _adultClient.id,
        tenantId: _adultClient.tenantId,
        fullName: _adultClient.fullName,
        status: _adultClient.status,
        metadata: patch.metadata ?? {},
        createdAt: _now,
        updatedAt: _now,
        email: _adultClient.email,
        phone: _adultClient.phone,
        clientTypeId: _adultClient.clientTypeId,
        dob: _adultClient.dob,
      );
    });

    c = ClientOnboardingController(
      repository: mock,
      session: session,
      softGateConfirm: (_) async => true,
      onFinished: (id) => finishedId = id,
    );
  });

  tearDown(() {
    c.dispose();
  });

  test(
    'adult happy path: Identity→Address→Preferences→Contacts→skip nominee→'
    'Funding→Legal→Finish',
    () async {
      // ── Identity (adult DOB) ──────────────────────────────────────────
      c.fullName.text = 'Alex Adult';
      c.email.text = 'alex@example.com';
      c.phone.text = '+61422222222';
      c.dob.value = DateTime(1990, 5, 15);
      c.ndisCtrl.text = '430118201';

      expect(await c.submitIdentity(), isTrue);
      expect(c.step.value, 1);
      expect(createCalls, hasLength(1));
      expect(createCalls.first.metadata?['onboarding_incomplete'], isTrue);
      expect(
        factUpserts.any((e) => e.$2 == OnboardingKeys.ndis),
        isTrue,
      );
      final ndisUpsert =
          factUpserts.firstWhere((e) => e.$2 == OnboardingKeys.ndis);
      expect(ndisUpsert.$1, 'client-adult-1');
      expect(ndisUpsert.$3.valueJson, '430118201');

      // ── Address ───────────────────────────────────────────────────────
      c.siteNameCtrl.text = 'Home';
      c.siteAddressCtrl.text = '1 George St';
      c.siteCityCtrl.text = 'Sydney';
      c.siteState.value = 'NSW';
      c.sitePostalCtrl.text = '2000';
      c.siteAccessNotesCtrl.text = 'Key under mat';

      await c.lookupSiteAddress();
      expect(c.geocodeFormattedAddress.value, isNotNull);
      c.confirmSiteAddress();
      expect(c.addressConfirmed.value, isTrue);

      expect(await c.submitAddress(), isTrue);
      expect(c.step.value, 2);
      expect(siteCreates, hasLength(1));
      expect(siteCreates.first.postalCode, '2000');
      expect(siteCreates.first.isPrimary, isTrue);
      expect(siteCreates.first.accessNotes, 'Key under mat');

      // ── Preferences ───────────────────────────────────────────────────
      c.preferredLanguageCtrl.text = 'English';
      c.homeVisitConsent.value = true;
      c.preferredContactMethod.value = 'phone';

      expect(await c.submitPreferences(), isTrue);
      expect(c.step.value, 3);

      // ── Emergency contact ─────────────────────────────────────────────
      c.contactNameCtrl.text = 'Sam Emergency';
      c.contactPhoneCtrl.text = '+61433333333';
      c.contactRelationshipPreset.value = OnboardingKeys.relEmergency;
      c.contactIsPrimary.value = true;

      expect(await c.submitContacts(), isTrue);
      expect(c.step.value, 4);
      expect(c.emergencySaved.value, isTrue);
      expect(
        contactCreates.any((r) => r.relationship == OnboardingKeys.relEmergency),
        isTrue,
      );
      final emergency = contactCreates
          .firstWhere((r) => r.relationship == OnboardingKeys.relEmergency);
      expect(emergency.name, 'Sam Emergency');
      expect(emergency.phone, '+61433333333');

      // ── Skip nominee (adult) ──────────────────────────────────────────
      expect(c.requiresChildRepresentative, isFalse);
      expect(c.nomineeOptional, isTrue);
      expect(await c.submitRepresentative(), isTrue);
      expect(c.nomineeSkipped.value, isTrue);
      expect(c.step.value, 5);
      expect(
        contactCreates
            .any((r) => r.relationship == OnboardingKeys.relNominee),
        isFalse,
      );

      // ── Funding self_managed ──────────────────────────────────────────
      c.planManagementType.value = 'self_managed';
      expect(await c.submitFunding(), isTrue);
      expect(c.step.value, 6);
      expect(
        factUpserts.any(
          (e) =>
              e.$2 == OnboardingKeys.planManagementType &&
              e.$3.valueJson == 'self_managed',
        ),
        isTrue,
      );

      // ── Legal complete (mock uploads) ─────────────────────────────────
      c.consentComplete.value = true;
      c.serviceAgreementComplete.value = true;

      // ── Finish ────────────────────────────────────────────────────────
      expect(await c.finishOnboarding(), isTrue);
      expect(finishedId, 'client-adult-1');
      expect(patchCalls, isNotEmpty);
      expect(
        patchCalls.last.metadata?['onboarding_incomplete'],
        isFalse,
      );
      expect(c.client.value?.metadata?['onboarding_incomplete'], isFalse);

      // Create still had incomplete=true; finish cleared it.
      expect(createCalls.first.metadata?['onboarding_incomplete'], isTrue);
      verify(() => mock.createClient(any())).called(1);
      verify(
        () => mock.upsertProfileFact(
          'client-adult-1',
          OnboardingKeys.ndis,
          any(),
        ),
      ).called(1);
      verify(() => mock.createSite('client-adult-1', any())).called(1);
      verify(() => mock.createContact('client-adult-1', any())).called(1);
      verify(() => mock.patchClient('client-adult-1', any())).called(1);
    },
  );
}
