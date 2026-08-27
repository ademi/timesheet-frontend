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

void main() {
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
      'other',
    ]);
    expect(ContactFormHost.kinshipPresets.containsKey('emergency'), isFalse);
    expect(ContactFormHost.kinshipPresets['carer'], 'Carer');
    expect(ContactFormHost.legalRolePresets, {
      OnboardingKeys.relChildRepresentative: 'Child representative',
      OnboardingKeys.relNominee: 'Nominee',
    });
  });

  group('contact form UI', () {
    late _MockClientsRepository clients;
    late _MockJobsRepository jobs;
    late _MockSessionService session;

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
      Get.put(
        ClientsController(
          repository: clients,
          session: session,
          jobsRepository: jobs,
        ),
      );
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
      await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
      await tester.pumpAndSettle();
      expect(find.text('Jane Mother').hitTestable(), findsWidgets);
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
