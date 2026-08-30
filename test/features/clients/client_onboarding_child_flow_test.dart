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

final _childClient = ClientOut(
  id: 'client-child-1',
  tenantId: 'tenant-1',
  fullName: 'Casey Child',
  status: 'active',
  metadata: const {'onboarding_incomplete': true},
  createdAt: _now,
  updatedAt: _now,
  email: 'parent@example.com',
  phone: '+61444444444',
  clientTypeId: 'type-patient',
  dob: '2015-03-10',
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
    contactCreates = [];
    finishedId = null;

    when(() => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')))
        .thenAnswer((_) async => <FormTemplateSummary>[]);
    when(() => mock.listClientTypes()).thenAnswer((_) async => [_patientType]);

    when(() => mock.createClient(any())).thenAnswer((_) async => _childClient);

    when(() => mock.upsertProfileFact(any(), any(), any()))
        .thenAnswer((_) async {});

    when(() => mock.geocode(any())).thenAnswer(
      (_) async => const GeocodeResponse(
        latitude: -33.8688,
        longitude: 151.2093,
        formattedAddress: '10 Park Ave, Sydney NSW 2000',
      ),
    );

    when(() => mock.createSite(any(), any())).thenAnswer((inv) async {
      final body = inv.positionalArguments[1] as ClientSiteWriteRequest;
      return ClientSiteOut(
        id: 'site-child-1',
        tenantId: 'tenant-1',
        clientId: 'client-child-1',
        name: body.name,
        addressLine1: body.addressLine1,
        city: body.city,
        state: body.state,
        country: body.country,
        postalCode: body.postalCode,
        latitude: body.latitude,
        longitude: body.longitude,
        geofenceRadiusM: body.geofenceRadiusM,
        isPrimary: body.isPrimary ?? false,
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
        clientId: 'client-child-1',
        name: body.name,
        email: body.email,
        phone: body.phone,
        relationship: body.relationship,
        isPrimary: body.isPrimary ?? false,
        notifyVisitComplete: body.notifyVisitComplete ?? false,
        isEmergency: body.isEmergency ?? false,
      );
    });

    when(() => mock.getClient(any())).thenAnswer((_) async => c.client.value!);

    when(() => mock.patchClient(any(), any())).thenAnswer((inv) async {
      final patch = inv.positionalArguments[1] as ClientUpdateRequest;
      return ClientOut(
        id: _childClient.id,
        tenantId: _childClient.tenantId,
        fullName: _childClient.fullName,
        status: _childClient.status,
        metadata: patch.metadata ?? {},
        createdAt: _now,
        updatedAt: _now,
        email: _childClient.email,
        phone: _childClient.phone,
        clientTypeId: _childClient.clientTypeId,
        dob: _childClient.dob,
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

  Future<void> walkToRepresentativeStep() async {
    c.fullName.text = 'Casey Child';
    c.email.text = 'casey@example.com';
    c.phone.text = '+61444444444';
    c.dob.value = DateTime(2015, 3, 10);
    expect(await c.submitIdentity(), isTrue);
    expect(c.requiresChildRepresentative, isTrue);

    c.siteNameCtrl.text = 'Home';
    c.siteAddressCtrl.text = '10 Park Ave';
    c.siteCityCtrl.text = 'Sydney';
    c.sitePostalCtrl.text = '2000';
    await c.lookupSiteAddress();
    c.confirmSiteAddress();
    expect(await c.submitAddress(), isTrue);

    expect(await c.submitPreferences(), isTrue);

    c.contactNameCtrl.text = 'Parent Emergency';
    c.contactPhoneCtrl.text = '+61455555555';
    c.contactRelationshipPreset.value = 'mother';
    c.contactIsEmergency.value = true;
    expect(await c.submitContacts(), isTrue);
    expect(c.step.value, 4);
    expect(c.contactRelationshipPreset.value,
        OnboardingKeys.relChildRepresentative);
  }

  test(
    'child path: cannot advance Representative without child_representative; '
    'adding rep unlocks finish and creates contact',
    () async {
      await walkToRepresentativeStep();

      // Blocked without child representative.
      expect(c.representativeSaved.value, isFalse);
      expect(await c.submitRepresentative(), isFalse);
      expect(c.errorMessage.value, contains('child representative'));
      expect(c.step.value, 4);
      expect(
        contactCreates
            .any((r) => r.relationship == OnboardingKeys.relChildRepresentative),
        isFalse,
      );

      // Add child representative → can advance.
      c.contactNameCtrl.text = 'Jamie Guardian';
      c.contactPhoneCtrl.text = '+61466666666';
      c.contactEmailCtrl.text = 'jamie@example.com';
      c.contactRelationshipPreset.value = OnboardingKeys.relChildRepresentative;

      expect(await c.submitRepresentative(), isTrue);
      expect(c.representativeSaved.value, isTrue);
      expect(c.step.value, 5);
      expect(
        contactCreates
            .any((r) => r.relationship == OnboardingKeys.relChildRepresentative),
        isTrue,
      );
      final childRep = contactCreates.firstWhere(
        (r) => r.relationship == OnboardingKeys.relChildRepresentative,
      );
      expect(childRep.name, 'Jamie Guardian');
      expect(childRep.phone, '+61466666666');

      // Funding → Legal (mock) → Finish.
      c.ndisCtrl.text = '431234567';
      c.planManagementType.value = 'self_managed';
      expect(await c.submitSupportPlan(), isTrue);
      expect(c.step.value, 6);

      c.consentComplete.value = true;
      c.serviceAgreementComplete.value = true;

      expect(await c.finishOnboarding(), isTrue);
      expect(finishedId, 'client-child-1');

      verify(() => mock.createContact('client-child-1', any())).called(2);
      expect(
        contactCreates.map((r) => r.relationship).toList(),
        containsAll([
          'mother',
          OnboardingKeys.relChildRepresentative,
        ]),
      );
    },
  );
}
