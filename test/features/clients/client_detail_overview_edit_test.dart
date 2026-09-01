import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/controllers/requirement_draft.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';
import 'package:rostiq/features/clients/views/client_detail_view.dart';
import 'package:rostiq/features/clients/widgets/client_detail_overview_section.dart';
import 'package:rostiq/features/clients/widgets/client_detail_profile_section.dart';
import 'package:rostiq/features/clients/widgets/client_requirement_editors.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';
import 'package:rostiq/shared/widgets/form_sticky_actions.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeClientUpdateRequest extends Fake implements ClientUpdateRequest {}

class _FakeProfileFactUpsert extends Fake implements ProfileFactUpsert {}

class _FakeClientFormSubmitRequest extends Fake
    implements ClientFormSubmitRequest {}

class _FakeClientLegalAcceptRequest extends Fake
    implements ClientLegalAcceptRequest {}

final _now = DateTime.utc(2026, 8, 27, 9);

final _patientType = ClientTypeOut(
  id: 'type-patient',
  code: 'patient',
  name: 'Patient',
  isActive: true,
  sortOrder: 1,
);

final _orgType = ClientTypeOut(
  id: 'type-org',
  code: 'organisation',
  name: 'Organisation',
  isActive: true,
  sortOrder: 2,
);

const _ndisReq = ClientTypeRequirement(
  requirementKey: 'ndis',
  label: 'NDIS number',
  sortOrder: 0,
  kind: 'field',
  captureModes: ['field', 'document'],
  fieldSchemaJson: {'placeholder': '430123456'},
  isRequired: true,
  valueType: 'text',
);

const _dobReq = ClientTypeRequirement(
  requirementKey: 'dob',
  label: 'Date of birth',
  sortOrder: 0,
  kind: 'field',
  captureModes: ['field'],
  fieldSchemaJson: <String, dynamic>{},
  isRequired: false,
  valueType: 'date',
);

const _idReq = ClientTypeRequirement(
  requirementKey: 'identity_100_point',
  label: '100-point ID',
  sortOrder: 1,
  kind: 'document',
  captureModes: ['document'],
  fieldSchemaJson: <String, dynamic>{},
  isRequired: false,
);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Demo Patient',
  status: 'active',
  email: 'demo@example.com',
  phone: '+61400000100',
  dob: '1990-05-15',
  clientTypeId: 'type-patient',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockClientsRepository clients;
  late _MockJobsRepository jobs;
  late _MockSessionService session;
  late ClientsController controller;

  setUpAll(() {
    registerFallbackValue(_FakeClientUpdateRequest());
    registerFallbackValue(_FakeProfileFactUpsert());
    registerFallbackValue(_FakeClientFormSubmitRequest());
    registerFallbackValue(_FakeClientLegalAcceptRequest());
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clients = _MockClientsRepository();
    jobs = _MockJobsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => clients.listClients()).thenAnswer((_) async => [_client]);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    when(() => clients.listClientTypes()).thenAnswer((_) async => [_patientType]);
    when(
      () => clients.listTypeRequirements(_patientType.id),
    ).thenAnswer((_) async => const [_ndisReq, _dobReq, _idReq]);
    when(() => clients.getClient(_client.id)).thenAnswer((_) async => _client);
    when(() => clients.getClientProfile(_client.id)).thenAnswer(
      (_) async => const ClientProfileBundle(facts: []),
    );
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.listContacts(any())).thenAnswer((_) async => []);
    when(() => clients.listSupportPlans(any())).thenAnswer((_) async => []);
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: jobs,
    );
    controller.selected.value = _client;
    controller.tabIndex.value = ClientsController.tabOverview;
    controller.hydrateOverviewDrafts();
    Get.put(controller);
  });

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  Finder documentPicker() => find.byIcon(Icons.upload_file_outlined);

  testWidgets('Overview shows identity fields read-only by default', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClientDetailOverviewSection(controller: controller),
          ),
        ),
      ),
    );

    expect(find.byKey(ClientDetailOverviewSection.editKey), findsOneWidget);
    expect(find.byKey(ClientDetailOverviewSection.fullNameKey), findsNothing);
    expect(find.text('Demo Patient'), findsOneWidget);
    expect(find.text('demo@example.com'), findsOneWidget);
  });

  testWidgets('Overview Edit reveals editable identity fields', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClientDetailOverviewSection(controller: controller),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(ClientDetailOverviewSection.editKey));
    await tester.pumpAndSettle();

    expect(find.byKey(ClientDetailOverviewSection.fullNameKey), findsOneWidget);
    expect(find.byKey(ClientDetailOverviewSection.emailKey), findsOneWidget);
    expect(find.byKey(ClientDetailOverviewSection.phoneKey), findsOneWidget);
    expect(find.byKey(ClientDetailOverviewSection.dobKey), findsOneWidget);
    expect(find.byKey(ClientDetailOverviewSection.ndisKey), findsOneWidget);
    expect(find.textContaining('Date of birth'), findsOneWidget);
    expect(find.text('NDIS number'), findsOneWidget);
  });

  testWidgets('Overview NDIS field has no document picker', (tester) async {
    controller.overviewEditing.value = true;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ClientDetailOverviewSection(controller: controller),
        ),
      ),
    );

    expect(find.byKey(ClientDetailOverviewSection.ndisKey), findsOneWidget);
    expect(documentPicker(), findsNothing);
    expect(find.byKey(ClientRequirementEditor.documentPickerKey), findsNothing);
  });

  testWidgets('Overview tab shows sticky Save and Cancel in edit mode', (
    tester,
  ) async {
    controller.overviewEditing.value = true;
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    expect(find.byType(FormStickyActions), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save type & profile'), findsNothing);
  });

  testWidgets('Overview Cancel restores draft edits', (tester) async {
    controller.overviewEditing.value = true;
    controller.overviewNameCtrl.text = 'Changed Name';
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(controller.overviewNameCtrl.text, _client.fullName);
    expect(controller.overviewEditing.value, isFalse);
  });

  testWidgets('Profile section has no DOB or NDIS editors', (tester) async {
    final ndisDraft = RequirementDraft(_ndisReq);
    final dobDraft = RequirementDraft(_dobReq);
    final idDraft = RequirementDraft(_idReq);
    addTearDown(ndisDraft.dispose);
    addTearDown(dobDraft.dispose);
    addTearDown(idDraft.dispose);
    controller.requirementDrafts.assignAll([ndisDraft, dobDraft, idDraft]);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClientDetailProfileSection(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('NDIS number *'), findsNothing);
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('100-point ID'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('Overview hides Type dropdown when only Patient exists', (
    tester,
  ) async {
    controller.clientTypes.assignAll([_patientType]);
    controller.overviewClientTypeId.value = _patientType.id;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ClientDetailOverviewSection(controller: controller),
        ),
      ),
    );

    expect(find.text('Type'), findsNothing);
    expect(find.byKey(ClientDetailOverviewSection.typeKey), findsNothing);
  });

  testWidgets('Overview shows Type dropdown when non-Patient type exists', (
    tester,
  ) async {
    controller.clientTypes.assignAll([_patientType, _orgType]);
    controller.overviewClientTypeId.value = _patientType.id;
    controller.overviewEditing.value = true;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ClientDetailOverviewSection(controller: controller),
        ),
      ),
    );

    expect(find.text('Type'), findsOneWidget);
    expect(find.byKey(ClientDetailOverviewSection.typeKey), findsOneWidget);
  });

  test('saveOverviewProfile uses patchClient and upsertProfileFact only', () async {
    controller.overviewNameCtrl.text = 'Updated Name';
    controller.overviewEmailCtrl.text = 'new@example.com';
    controller.overviewNdisCtrl.text = '430999888';
    controller.overviewDob.value = DateTime(1991, 6, 20);
    controller.tabIndex.value = ClientsController.tabOverview;

    when(() => clients.patchClient(any(), any())).thenAnswer((_) async => _client);
    when(
      () => clients.upsertProfileFact(any(), OnboardingKeys.ndis, any()),
    ).thenAnswer((_) async {});

    await controller.saveOverviewProfile();

    verify(() => clients.patchClient(_client.id, any())).called(1);
    verify(
      () => clients.upsertProfileFact(
        _client.id,
        OnboardingKeys.ndis,
        any(that: predicate<ProfileFactUpsert>((p) => p.valueJson == '430999888')),
      ),
    ).called(1);
    expect(controller.tabIndex.value, ClientsController.tabOverview);
  });

  test('saveOverviewProfile never calls saveClientTypeProfile path', () async {
    controller.overviewEmailCtrl.text = 'patch@example.com';
    when(() => clients.patchClient(any(), any())).thenAnswer((_) async => _client);

    await controller.saveOverviewProfile();

    verifyNever(() => clients.submitClientForm(any(), any(), any()));
    verifyNever(() => clients.acceptClientLegal(any(), any(), any()));
  });

  testWidgets('saveClientTypeProfile preserves dirty Overview DOB', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );

    controller.overviewDob.value = DateTime(1988, 3, 10);
    controller.selectedClientTypeId.value = _patientType.id;
    controller.clientTypes.assignAll([_patientType]);
    controller.requirementDrafts.clear();

    when(() => clients.patchClient(any(), any())).thenAnswer((_) async => _client);
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.listContacts(any())).thenAnswer((_) async => []);

    await controller.saveClientTypeProfile();
    await tester.pumpAndSettle();

    expect(controller.overviewDob.value, DateTime(1988, 3, 10));
    expect(controller.isOverviewDirty, isTrue);
  });

  testWidgets('saveClientTypeProfile does not patch DOB from profile drafts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );

    final dobDraft = RequirementDraft(_dobReq);
    dobDraft.dateValue.value = DateTime(1985, 1, 1);
    controller.requirementDrafts.assignAll([dobDraft]);
    controller.overviewDob.value = DateTime(1990, 5, 15);
    controller.selectedClientTypeId.value = _patientType.id;
    controller.clientTypes.assignAll([_patientType]);

    when(() => clients.patchClient(any(), any())).thenAnswer((_) async => _client);
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.listContacts(any())).thenAnswer((_) async => []);

    await controller.saveClientTypeProfile();
    await tester.pumpAndSettle();

    final captured = verify(
      () => clients.patchClient(_client.id, captureAny()),
    ).captured.single as ClientUpdateRequest;
    expect(captured.dob, isNull);
  });

  testWidgets('NdisCapturePrompt opens Overview tab', (tester) async {
    final noNdisClient = ClientOut(
      id: 'client-2',
      tenantId: 'tenant-1',
      fullName: 'No NDIS',
      status: 'active',
      clientTypeId: 'type-patient',
      metadata: const {},
      createdAt: _now,
      updatedAt: _now,
    );
    controller.selected.value = noNdisClient;
    controller.clientTypes.assignAll([_patientType]);
    controller.selectedClientTypeId.value = _patientType.id;
    controller.overviewClientTypeId.value = _patientType.id;
    controller.profileFacts.clear();
    controller.tabIndex.value = ClientsController.tabProfile;
    controller.hydrateOverviewDrafts();

    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    expect(find.text('Add NDIS details'), findsOneWidget);
    await tester.tap(find.text('Add NDIS details'));
    await tester.pump();

    expect(controller.tabIndex.value, ClientsController.tabOverview);
  });

  test('saveOverviewProfile blank email keeps existing (I2)', () async {
    controller.hydrateOverviewDrafts();
    controller.overviewEmailCtrl.text = '';
    controller.overviewPhoneCtrl.text = '+61400000100';
    when(() => clients.patchClient(any(), any())).thenAnswer((_) async => _client);

    await controller.saveOverviewProfile();

    final captured =
        verify(() => clients.patchClient(_client.id, captureAny())).captured.single
            as ClientUpdateRequest;
    expect(captured.email, 'demo@example.com');
    expect(controller.overviewEmailCtrl.text, 'demo@example.com');
  });

  test('saveOverviewProfile null DOB keeps existing (I3)', () async {
    controller.hydrateOverviewDrafts();
    controller.overviewDob.value = null;
    when(() => clients.patchClient(any(), any())).thenAnswer((_) async => _client);

    await controller.saveOverviewProfile();

    final captured =
        verify(() => clients.patchClient(_client.id, captureAny())).captured.single
            as ClientUpdateRequest;
    expect(captured.dob, '1990-05-15');
  });

  test('syncFormDraftsFromOverview copies dirty Overview identity (I5)', () {
    controller.hydrateOverviewDrafts();
    controller.overviewNameCtrl.text = 'Edited On Overview';
    controller.overviewEmailCtrl.text = 'ov@example.com';
    controller.overviewPhoneCtrl.text = '+61400999888';
    controller.overviewStatus.value = 'inactive';

    expect(controller.isOverviewDirty, isTrue);
    controller.syncFormDraftsFromOverview();

    expect(controller.nameCtrl.text, 'Edited On Overview');
    expect(controller.emailCtrl.text, 'ov@example.com');
    expect(controller.phoneCtrl.text, '+61400999888');
    expect(controller.status.value, 'inactive');
  });
}
