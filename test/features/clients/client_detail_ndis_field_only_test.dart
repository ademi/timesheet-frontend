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
import 'package:rostiq/features/clients/widgets/client_detail_profile_section.dart';
import 'package:rostiq/features/clients/widgets/client_requirement_editors.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

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
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

void main() {
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
    when(() => clients.listClients()).thenAnswer((_) async => [_client]);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: jobs,
    );
    Get.put(controller);
  });

  tearDown(Get.reset);

  Finder documentPicker() => find.byIcon(Icons.upload_file_outlined);

  testWidgets(
    'ndis editor does not show document picker even when capture_modes include document',
    (tester) async {
      final draft = RequirementDraft(_ndisReq);
      addTearDown(draft.dispose);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ClientRequirementEditor(
              controller: controller,
              draft: draft,
            ),
          ),
        ),
      );

      expect(find.text('NDIS number *'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(documentPicker(), findsNothing);
      expect(
        find.byKey(ClientRequirementEditor.documentPickerKey),
        findsNothing,
      );
      expect(find.text('Upload file'), findsNothing);
      expect(find.text('Add file(s)'), findsNothing);
      expect(find.text('Choose from photos'), findsNothing);
    },
  );

  testWidgets('non-ndis document requirement still shows document picker', (
    tester,
  ) async {
    final draft = RequirementDraft(_idReq);
    addTearDown(draft.dispose);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ClientRequirementEditor(
            controller: controller,
            draft: draft,
          ),
        ),
      ),
    );

    expect(documentPicker(), findsOneWidget);
    expect(find.byKey(ClientRequirementEditor.documentPickerKey), findsOneWidget);
    expect(find.text('Upload file'), findsOneWidget);
  });

  testWidgets('Details hides Type dropdown when only Patient exists', (
    tester,
  ) async {
    controller.clientTypes.assignAll([_patientType]);
    controller.selectedClientTypeId.value = _patientType.id;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClientDetailProfileSection(controller: controller),
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Select a type to show optional profile requirements and documents.',
      ),
      findsNothing,
    );
    expect(find.text('Type'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('Details shows Type dropdown when a non-Patient type exists', (
    tester,
  ) async {
    controller.clientTypes.assignAll([_patientType, _orgType]);
    controller.selectedClientTypeId.value = _patientType.id;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClientDetailProfileSection(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('Type'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(
      find.text(
        'Select a type to show optional profile requirements and documents.',
      ),
      findsNothing,
    );
  });

  test(
    'loadTypeTabForSelected defaults selectedClientTypeId to Patient when null',
    () async {
      controller.selected.value = _client;
      when(
        () => clients.listClientTypes(),
      ).thenAnswer((_) async => [_patientType]);
      when(
        () => clients.listTypeRequirements(_patientType.id),
      ).thenAnswer((_) async => const [_ndisReq]);
      when(() => clients.getClientProfile(_client.id)).thenAnswer(
        (_) async => const ClientProfileBundle(),
      );

      expect(controller.selectedClientTypeId.value, isNull);
      await controller.loadTypeTabForSelected();

      expect(controller.selectedClientTypeId.value, _patientType.id);
    },
  );
}
