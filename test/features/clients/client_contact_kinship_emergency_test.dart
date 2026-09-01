import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/themes/app_colors.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';
import 'package:rostiq/features/clients/views/client_contact_form_view.dart';
import 'package:rostiq/features/clients/views/client_onboarding_view.dart';
import 'package:rostiq/features/clients/widgets/client_detail_contacts_section.dart';
import 'package:rostiq/features/clients/widgets/contact_form_host.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeClientContactWriteRequest extends Fake
    implements ClientContactWriteRequest {}

final _now = DateTime.utc(2026, 8, 27, 9);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Sam Client',
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeClientContactWriteRequest());
  });
  test('kinshipPresets omit Emergency; legal roles stay on representative', () {
    expect(ContactFormHost.kinshipPresets.keys, [
      'mother',
      'father',
      'son',
      'daughter',
      'sibling',
      'spouse',
      'friend',
      'neighbour',
      'carer',
    ]);
    expect(ContactFormHost.kinshipPresets.containsKey('emergency'), isFalse);
    expect(ContactFormHost.kinshipPresets['carer'], 'Carer');
    expect(ContactFormHost.kinshipPresets.containsKey('other'), isFalse);
    expect(ContactFormHost.legalRolePresets, {
      OnboardingKeys.relChildRepresentative: 'Child representative',
      OnboardingKeys.relNominee: 'Nominee',
    });
  });

  group('relationship Other (CR5)', () {
    test('hydrateRelationship maps custom text to _other sentinel', () {
      final hydrated = ContactFormHost.hydrateRelationship('Godparent');
      expect(hydrated.preset, ContactFormHost.relationshipOtherKey);
      expect(hydrated.otherText, 'Godparent');
    });

    test('hydrateRelationship maps stored other to _other with empty text', () {
      final hydrated = ContactFormHost.hydrateRelationship('other');
      expect(hydrated.preset, ContactFormHost.relationshipOtherKey);
      expect(hydrated.otherText, isEmpty);
    });

    test('hydrateRelationship keeps known kinship presets', () {
      final hydrated = ContactFormHost.hydrateRelationship('mother');
      expect(hydrated.preset, 'mother');
      expect(hydrated.otherText, isEmpty);
    });
  });

  group('contact form UI', () {
    late _MockClientsRepository clients;
    late _MockJobsRepository jobs;
    late _MockSessionService session;
    late ClientsController controller;

    setUp(() {
      Get.testMode = true;
      Get.reset();
      clients = _MockClientsRepository();
      jobs = _MockJobsRepository();
      session = _MockSessionService();
      when(() => session.hasPermission(any())).thenReturn(true);
      when(() => clients.listClients()).thenAnswer((_) async => []);
      when(() => clients.getClientProfilePhoto(any())).thenAnswer(
        (_) async => const ProfilePhotoOut(hasPhoto: false),
      );
      controller = ClientsController(
        repository: clients,
        session: session,
        jobsRepository: jobs,
      );
      Get.put(controller);
      controller.selected.value = _client;
    });

    tearDown(Get.reset);

    testWidgets('shows Emergency contact checkbox and kinship, not Emergency preset',
        (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(home: ClientContactFormView()),
      );

      expect(find.text('Emergency contact'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      expect(find.text('Mother').hitTestable(), findsWidgets);
      expect(find.text('Carer').hitTestable(), findsWidgets);
      expect(find.text('Emergency'), findsNothing);
    });

    testWidgets('Other requires non-empty free text before save', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(home: ClientContactFormView()),
      );

      controller.contactNameCtrl.text = 'Alex';
      controller.contactPhoneCtrl.text = '+61400000001';
      controller.contactRelationshipPreset.value =
          ContactFormHost.relationshipOtherKey;

      await tester.tap(find.text('Create contact'));
      await tester.pumpAndSettle();

      expect(controller.errorMessage.value, contains('Specify the relationship'));
      verifyNever(() => clients.createContact(any(), any()));
    });

    test('custom Other resolves typed string for save', () {
      controller.contactRelationshipPreset.value =
          ContactFormHost.relationshipOtherKey;
      controller.contactRelationshipOtherCtrl.text = 'Godparent';

      expect(controller.resolvedContactRelationship, 'Godparent');
      expect(controller.resolvedContactRelationship, isNot('other'));
    });

    testWidgets('custom Other reopens with sentinel and free text', (tester) async {
      final hydrated = ContactFormHost.hydrateRelationship('Godparent');
      controller.contactRelationshipPreset.value = hydrated.preset;
      controller.contactRelationshipOtherCtrl.text = hydrated.otherText;

      await tester.pumpWidget(
        const GetMaterialApp(home: ClientContactFormView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Relationship (other)'), findsOneWidget);
      expect(controller.contactRelationshipOtherCtrl.text, 'Godparent');
    });

    testWidgets('stored other hydrates to Other sentinel with empty text',
        (tester) async {
      final hydrated = ContactFormHost.hydrateRelationship('other');
      controller.contactRelationshipPreset.value = hydrated.preset;
      controller.contactRelationshipOtherCtrl.text = hydrated.otherText;

      await tester.pumpWidget(
        const GetMaterialApp(home: ClientContactFormView()),
      );
      await tester.pumpAndSettle();

      expect(
        controller.contactRelationshipPreset.value,
        ContactFormHost.relationshipOtherKey,
      );
      expect(controller.contactRelationshipOtherCtrl.text, isEmpty);
      expect(find.text('Relationship (other)'), findsOneWidget);
    });

    test('selecting non-Other clears companion text', () {
      controller.contactRelationshipPreset.value =
          ContactFormHost.relationshipOtherKey;
      controller.contactRelationshipOtherCtrl.text = 'Cousin';

      controller.contactRelationshipPreset.value = 'mother';
      controller.contactRelationshipOtherCtrl.clear();

      expect(controller.contactRelationshipPreset.value, 'mother');
      expect(controller.contactRelationshipOtherCtrl.text, isEmpty);
    });
  });

  group('onboarding steps', () {
    late _MockClientsRepository mock;
    late _MockSessionService session;

    setUp(() {
      Get.testMode = true;
      Get.reset();
      mock = _MockClientsRepository();
      session = _MockSessionService();
      when(() => session.hasPermission(any())).thenReturn(true);
      when(
        () => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
      ).thenAnswer((_) async => <FormTemplateSummary>[]);
      Get.put(ClientOnboardingController(repository: mock, session: session));
    });

    tearDown(Get.reset);

    testWidgets('contacts step uses kinship dropdown, not locked Emergency',
        (tester) async {
      final c = Get.find<ClientOnboardingController>();
      c.step.value = 3;

      await tester.pumpWidget(
        const GetMaterialApp(home: ClientOnboardingView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency contact'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      expect(find.text('Mother').hitTestable(), findsWidgets);
      expect(find.text('Emergency'), findsNothing);
    });

    testWidgets('representative shows also-emergency and pick existing',
        (tester) async {
      final c = Get.find<ClientOnboardingController>();
      c.dob.value = DateTime(1990, 1, 1);
      c.step.value = 4;
      c.contactsCreated.add(
        const ClientContactOut(
          id: 'c-existing',
          tenantId: 'tenant-1',
          clientId: 'client-1',
          name: 'Jane Mother',
          relationship: 'mother',
          isPrimary: false,
          notifyVisitComplete: false,
        ),
      );

      await tester.pumpWidget(
        const GetMaterialApp(home: ClientOnboardingView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Also emergency contact'), findsOneWidget);
      expect(find.text('Use existing contact as emergency'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);

      c.reuseEmergencyContactId.value = 'c-existing';
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsNothing);
      expect(find.text('Jane Mother'), findsWidgets);
      expect(find.text('Marked as emergency contact'), findsOneWidget);
      expect(find.text('Save as nominee'), findsOneWidget);
    });
  });

  testWidgets('detail contacts section shows Emergency chip when isEmergency',
      (tester) async {
    const emergency = ClientContactOut(
      id: 'c1',
      tenantId: 't',
      clientId: 'c',
      name: 'Jane Mother',
      relationship: 'mother',
      isPrimary: false,
      notifyVisitComplete: false,
      isEmergency: true,
    );
    const other = ClientContactOut(
      id: 'c2',
      tenantId: 't',
      clientId: 'c',
      name: 'Alex Friend',
      relationship: 'friend',
      isPrimary: false,
      notifyVisitComplete: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientDetailContactsSection(
            contacts: const [emergency, other],
            canManage: false,
            onAdd: () {},
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Jane Mother'), findsOneWidget);
    expect(find.text('Alex Friend'), findsOneWidget);

    final chip = tester.widget<Chip>(find.byType(Chip));
    expect(chip.backgroundColor, AppColors.openSlotBackground);
    expect(chip.labelStyle?.color, AppColors.openSlot);
  });
}
