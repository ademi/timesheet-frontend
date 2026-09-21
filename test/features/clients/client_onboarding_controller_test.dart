import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/models/identity_card_attachment.dart';
import 'package:rostiq/features/clients/models/support_plan_specialist_types.dart';
import 'package:rostiq/features/clients/utils/clinical_keys.dart';
import 'package:rostiq/features/clients/models/legal_other_document.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';
import 'package:rostiq/features/clients/widgets/contact_form_host.dart';
import 'package:rostiq/features/clients/widgets/onboarding/onboarding_identity_step.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockJobsRepository extends Mock implements JobsRepository {}

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
    Future<PendingIdentityCardFile?> Function()? pickCardFile,
  }) {
    return ClientOnboardingController(
      repository: mock,
      session: sessionOverride ?? session,
      documentPipeline: documentPipeline,
      pickPdfBytes: pickPdfBytes,
      pickCardFile: pickCardFile,
      softGateConfirm: softGateConfirm,
      onFinished: onFinished,
    );
  }

  void _fillValidIdentity(ClientOnboardingController controller) {
    controller.fullName.text = 'Sam Parent';
    controller.email.text = 'sam@example.com';
    controller.phone.text = '+61411111111';
    controller.dob.value = DateTime(1990, 5, 1);
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
    when(
      () => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
    ).thenAnswer((_) async => <FormTemplateSummary>[]);
    when(() => mock.listClientTypes()).thenAnswer((_) async => [_patientType]);
    c = _buildController();
  });

  tearDown(() {
    c.dispose();
  });

  test('cannot leave Identity without dob', () async {
    c.fullName.text = 'Sam';
    c.email.text = 'sam@example.com';
    c.phone.text = '+61411111111';
    expect(await c.submitIdentity(), isFalse);
    expect(c.errorMessage.value, contains('date of birth'));
    expect(c.step.value, 0);
  });

  test('cannot leave Identity without email', () async {
    c.fullName.text = 'Sam';
    c.phone.text = '+61411111111';
    c.dob.value = DateTime(1990, 1, 1);
    expect(await c.submitIdentity(), isFalse);
    expect(c.errorMessage.value, contains('email'));
    expect(c.step.value, 0);
  });

  test('cannot leave Identity without phone', () async {
    c.fullName.text = 'Sam';
    c.email.text = 'sam@example.com';
    c.dob.value = DateTime(1990, 1, 1);
    expect(await c.submitIdentity(), isFalse);
    expect(c.errorMessage.value, contains('phone'));
    expect(c.step.value, 0);
  });

  test('submitIdentity sets onboarding_incomplete and advances', () async {
    ClientCreateRequest? captured;
    when(() => mock.createClient(any())).thenAnswer((inv) async {
      captured = inv.positionalArguments.first as ClientCreateRequest;
      return _fakeClient;
    });
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async {});

    _fillValidIdentity(c);

    expect(await c.submitIdentity(), isTrue);
    expect(c.step.value, 1);
    expect(captured?.metadata?['onboarding_incomplete'], isTrue);
    expect(captured?.email, 'sam@example.com');
    expect(captured?.phone, '+61411111111');
    verifyNever(
      () => mock.upsertProfileFact('client-1', OnboardingKeys.ndis, any()),
    );
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


  test('submitNdisStep soft-skips when empty', () async {
    c.client.value = _fakeClient;
    c.step.value = 4;
    expect(await c.submitNdisStep(soft: true), isTrue);
    expect(c.step.value, 5);
    expect(c.errorMessage.value, isNull);
  });

  test('submitSupportPlan blocks without NDIS number', () async {
    c.client.value = _fakeClient;
    c.step.value = 4;
    c.planManagementType.value = 'self_managed';
    expect(await c.submitSupportPlan(), isFalse);
    expect(c.ndisFieldError.value, contains('NDIS'));
  });

  test(
    'submitSupportPlan blocks plan_managed without manager fields',
    () async {
      c.client.value = _fakeClient;
      c.step.value = 4;
      c.ndisCtrl.text = '431234567';
      c.planManagementType.value = 'plan_managed';
      expect(await c.submitSupportPlan(), isFalse);
      expect(c.errorMessage.value, contains('Plan manager'));
    },
  );

  test('submitSupportPlan accepts self_managed with NDIS', () async {
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async {});
    c.client.value = _fakeClient;
    c.step.value = 4;
    c.ndisCtrl.text = '431234567';
    c.planManagementType.value = 'self_managed';
    expect(await c.submitSupportPlan(), isTrue);
    expect(c.step.value, 5);
    verify(
      () => mock.upsertProfileFact(
        'client-1',
        OnboardingKeys.ndis,
        any(
          that: predicate<ProfileFactUpsert>((u) => u.valueJson == '431234567'),
        ),
      ),
    ).called(1);
    verifyNever(
      () => mock.upsertProfileFact(
        'client-1',
        OnboardingKeys.ndisPlanBudgets,
        any(),
      ),
    );
    verifyNever(
      () => mock.upsertProfileFact(
        'client-1',
        OnboardingKeys.supportPlanSpecialists,
        any(),
      ),
    );
  });

  test(
    'submitSupportPlan clears legacy budget keys when saving JSON',
    () async {
      final clearedKeys = <String>[];
      when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((inv) {
        final key = inv.positionalArguments[1] as String;
        final body = inv.positionalArguments[2] as ProfileFactUpsert;
        if (body.clearValue == true) {
          clearedKeys.add(key);
        }
        return Future.value();
      });

      c.hydrateSupportPlanFromFacts([
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.budgetCore,
          valueJson: 5000,
        ),
      ]);
      c.client.value = _fakeClient;
      c.step.value = 4;
      c.ndisCtrl.text = '431234567';
      c.planManagementType.value = 'self_managed';
      c.budgetCoreCtrl.text = '1000';

      expect(await c.submitSupportPlan(), isTrue);
      expect(clearedKeys, contains(OnboardingKeys.budgetCore));
      verify(
        () => mock.upsertProfileFact(
          'client-1',
          OnboardingKeys.ndisPlanBudgets,
          any(
            that: predicate<ProfileFactUpsert>(
              (u) => u.valueJson != null && u.clearValue != true,
            ),
          ),
        ),
      ).called(1);
    },
  );

  test('submitSupportPlan rejects negative budget values', () async {
    c.client.value = _fakeClient;
    c.step.value = 4;
    c.ndisCtrl.text = '431234567';
    c.planManagementType.value = 'self_managed';
    c.budgetCoreCtrl.text = '-50';
    expect(await c.submitSupportPlan(), isFalse);
    expect(c.budgetFieldError.value, contains('negative'));
  });

  test(
    'submitSupportPlan surfaces ndis_number_in_use on field error',
    () async {
      when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((
        inv,
      ) async {
        if (inv.positionalArguments[1] == OnboardingKeys.ndis) {
          throw const AppFailure(
            code: 'ndis_number_in_use',
            message: 'This NDIS number is already used by another client.',
            presentation: AppFailurePresentation.inline,
          );
        }
      });
      c.client.value = _fakeClient;
      c.step.value = 4;
      c.ndisCtrl.text = '431234567';
      c.planManagementType.value = 'self_managed';
      expect(await c.submitSupportPlan(), isFalse);
      expect(c.ndisFieldError.value, contains('already used'));
      expect(c.step.value, 4);
    },
  );

  test(
    'submitSupportPlan upserts plan manager expanded fields when plan_managed',
    () async {
      when(
        () => mock.upsertProfileFact(any(), any(), any()),
      ).thenAnswer((_) async {});
      c.client.value = _fakeClient;
      c.step.value = 4;
      c.ndisCtrl.text = '431234567';
      c.planManagementType.value = 'plan_managed';
      c.planManagerNameCtrl.text = 'Acme PM';
      c.planManagerCompanyCtrl.text = 'Acme Co';
      c.planManagerPhoneCtrl.text = '+61400000001';
      expect(await c.submitSupportPlan(), isTrue);
      verify(
        () => mock.upsertProfileFact(
          'client-1',
          OnboardingKeys.planManagerCompany,
          any(
            that: predicate<ProfileFactUpsert>((u) => u.valueJson == 'Acme Co'),
          ),
        ),
      ).called(1);
    },
  );

  test(
    'finishOnboarding soft gate warns then clears incomplete flag',
    () async {
      var softGateCalled = false;
      ClientUpdateRequest? patch;
      when(
        () => mock.getClient('client-1'),
      ).thenAnswer((_) async => _fakeClient);
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
      c.step.value = 8;

      expect(await c.finishOnboarding(), isTrue);
      expect(softGateCalled, isTrue);
      expect(patch?.metadata?['onboarding_incomplete'], isFalse);
      expect(finishedId, 'client-1');
    },
  );

  test('finishOnboarding aborts when soft gate declined', () async {
    c.dispose();
    c = _buildController(softGateConfirm: (_) async => false);
    c.client.value = _fakeClient;
    c.step.value = 8;
    expect(await c.finishOnboarding(), isFalse);
    verifyNever(() => mock.patchClient(any(), any()));
  });

  test(
    'finishOnboarding re-fetches client so photo_document_id is not wiped',
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
      c.step.value = 8;

      expect(await c.finishOnboarding(), isTrue);
      verify(() => mock.getClient('client-1')).called(1);
      expect(patch?.metadata?['onboarding_incomplete'], isFalse);
      expect(patch?.metadata?['photo_document_id'], 'doc-photo-1');
    },
  );

  test('finishOnboarding does not patch when getClient fails', () async {
    c.dispose();
    c = _buildController(
      softGateConfirm: (_) async => true,
      onFinished: (_) {},
    );
    c.client.value = _fakeClient;
    c.step.value = 8;

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

  test(
    'finishOnboarding maps unexpected errors to a generic message',
    () async {
      c.dispose();
      c = _buildController(
        softGateConfirm: (_) async => true,
        onFinished: (_) {},
      );
      c.client.value = _fakeClient;
      c.step.value = 8;

      when(
        () => mock.getClient('client-1'),
      ).thenThrow(StateError('secret-stack'));

      expect(await c.finishOnboarding(), isFalse);
      expect(c.errorMessage.value, isNot(contains('secret-stack')));
      expect(c.errorMessage.value, isNot(contains('StateError')));
      expect(c.errorMessage.value, 'Something went wrong. Please try again.');
      verifyNever(() => mock.patchClient(any(), any()));
    },
  );

  testWidgets('finishOnboarding replaces stack with client detail route', (
    tester,
  ) async {
    Get.testMode = true;
    Get.reset();
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.staffClientOnboarding,
        getPages: [
          GetPage(
            name: AppRoutes.staffClientOnboarding,
            page: () => const SizedBox.shrink(),
          ),
          GetPage(
            name: AppRoutes.staffClientDetail,
            page: () => const SizedBox.shrink(),
          ),
          GetPage(
            name: '/staff/clients/other',
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
    Get.toNamed('/staff/clients/other');

    when(() => mock.getClient('client-1')).thenAnswer((_) async => _fakeClient);
    when(() => mock.patchClient(any(), any())).thenAnswer(
      (inv) async => ClientOut(
        id: _fakeClient.id,
        tenantId: _fakeClient.tenantId,
        fullName: _fakeClient.fullName,
        status: _fakeClient.status,
        metadata:
            (inv.positionalArguments[1] as ClientUpdateRequest).metadata ?? {},
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    c.dispose();
    c = _buildController(softGateConfirm: (_) async => true);
    c.client.value = _fakeClient;
    c.step.value = 8;

    expect(await c.finishOnboarding(), isTrue);
    await tester.pumpAndSettle();
    expect(Get.currentRoute, startsWith(AppRoutes.staffClientDetail));
    expect(Get.parameters['id'], 'client-1');
  });

  testWidgets(
    'finishOnboarding without registered ClientsController hydrates via binding',
    (tester) async {
      Get.testMode = true;
      Get.reset();

      when(() => mock.listClients()).thenAnswer((_) async => [_fakeClient]);
      when(() => mock.getClient('client-1')).thenAnswer((_) async => _fakeClient);
      when(() => mock.patchClient(any(), any())).thenAnswer((_) async => _fakeClient);
      when(
        () => mock.getClientProfilePhoto(any()),
      ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
      when(() => mock.listClientTypes()).thenAnswer((_) async => []);
      when(
        () => mock.getClientProfile(any()),
      ).thenAnswer((_) async => const ClientProfileBundle(facts: []));
      when(() => mock.listSites(any())).thenAnswer((_) async => []);
      when(() => mock.listContacts(any())).thenAnswer((_) async => []);
      when(() => mock.listSupportPlans(any())).thenAnswer((_) async => []);
      when(() => mock.listTypeRequirements(any())).thenAnswer((_) async => []);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.staffClientOnboarding,
          getPages: [
            GetPage(
              name: AppRoutes.staffClientOnboarding,
              page: () => const SizedBox.shrink(),
            ),
            GetPage(
              name: AppRoutes.staffClientDetail,
              page: () => const SizedBox.shrink(),
              binding: BindingsBuilder(() {
                Get.put(
                  ClientsController(
                    repository: mock,
                    session: session,
                    jobsRepository: _MockJobsRepository(),
                  ),
                );
              }),
            ),
          ],
        ),
      );

      expect(Get.isRegistered<ClientsController>(), isFalse);

      c.dispose();
      c = _buildController(softGateConfirm: (_) async => true);
      c.client.value = _fakeClient;
      c.step.value = 8;

      expect(await c.finishOnboarding(), isTrue);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, startsWith(AppRoutes.staffClientDetail));
      expect(Get.parameters['id'], 'client-1');
      expect(Get.isRegistered<ClientsController>(), isTrue);
      final clientsCtrl = Get.find<ClientsController>();
      // onInit microtask hydrate + openDetailById
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(clientsCtrl.selected.value?.id, 'client-1');
    },
  );

  testWidgets(
    'finishOnboarding hydrates ClientsController.selected before detail route',
    (tester) async {
      Get.testMode = true;
      Get.reset();

      when(() => mock.listClients()).thenAnswer((_) async => [_fakeClient]);
      when(() => mock.getClient('client-1')).thenAnswer((_) async => _fakeClient);
      when(() => mock.patchClient(any(), any())).thenAnswer((_) async => _fakeClient);
      when(
        () => mock.getClientProfilePhoto(any()),
      ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
      when(() => mock.listClientTypes()).thenAnswer((_) async => []);
      when(
        () => mock.getClientProfile(any()),
      ).thenAnswer((_) async => const ClientProfileBundle(facts: []));
      when(() => mock.listSites(any())).thenAnswer((_) async => []);
      when(() => mock.listContacts(any())).thenAnswer((_) async => []);
      when(() => mock.listSupportPlans(any())).thenAnswer((_) async => []);
      when(
        () => mock.listTypeRequirements(any()),
      ).thenAnswer((_) async => []);

      final clientsCtrl = ClientsController(
        repository: mock,
        session: session,
        jobsRepository: _MockJobsRepository(),
      );
      Get.put(clientsCtrl);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.staffClientOnboarding,
          getPages: [
            GetPage(
              name: AppRoutes.staffClientOnboarding,
              page: () => const SizedBox.shrink(),
            ),
            GetPage(
              name: AppRoutes.staffClientDetail,
              page: () => const SizedBox.shrink(),
              binding: BindingsBuilder(() {
                if (!Get.isRegistered<ClientsController>()) {
                  Get.put(clientsCtrl);
                }
              }),
            ),
          ],
        ),
      );

      c.dispose();
      c = _buildController(softGateConfirm: (_) async => true);
      c.client.value = _fakeClient;
      c.step.value = 8;

      expect(await c.finishOnboarding(), isTrue);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, startsWith(AppRoutes.staffClientDetail));
      expect(Get.parameters['id'], 'client-1');
      expect(clientsCtrl.selected.value?.id, 'client-1');
    },
  );

  test(
    'lookupSiteAddress rejects low confidence like ClientsController',
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
    },
  );

  test('submitContacts allows advancing with no contacts', () async {
    c.client.value = _fakeClient;
    c.step.value = 3;
    c.dob.value = DateTime(1990, 1, 1);
    c.contactDraftMode.value = 'nominee';
    expect(await c.submitContactsStep(), isTrue);
    expect(c.errorMessage.value, isNull);
    expect(c.step.value, 4);
    expect(c.nomineeSkipped.value, isTrue);
  });

  test(
    'emergency draft on Contacts step does not get representative legal_role',
    () async {
      ClientContactWriteRequest? captured;
      when(() => mock.createContact(any(), any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[1] as ClientContactWriteRequest;
        return ClientContactOut(
          id: 'c-em',
          tenantId: 'tenant-1',
          clientId: 'client-1',
          name: captured!.name,
          phone: captured!.phone,
          relationship: captured!.relationship,
          legalRole: captured!.legalRole,
          isPrimary: captured!.isPrimary ?? false,
          notifyVisitComplete: captured!.notifyVisitComplete ?? false,
          isEmergency: captured!.isEmergency ?? true,
        );
      });

      c.client.value = _fakeClient;
      c.step.value = 3;
      c.dob.value = DateTime(2015, 1, 1); // under 18
      c.beginEmergencyDraft();
      c.contactNameCtrl.text = 'Emergency Parent';
      c.contactPhoneCtrl.text = '+61400000111';
      c.contactRelationshipPreset.value = 'mother';

      expect(await c.saveContactDraft(), isTrue);
      expect(captured!.legalRole, isNull);
      expect(c.representativeSaved.value, isFalse);
    },
  );

  test('edit representative patches existing contact on save', () async {
    when(() => mock.patchContact(any(), any(), any())).thenAnswer((inv) async {
      final body = inv.positionalArguments[2] as ClientContactWriteRequest;
      return ClientContactOut(
        id: 'rep-1',
        tenantId: 'tenant-1',
        clientId: 'client-1',
        name: body.name,
        phone: body.phone,
        relationship: body.relationship,
        legalRole: body.legalRole,
        isPrimary: body.isPrimary ?? false,
        notifyVisitComplete: body.notifyVisitComplete ?? false,
        isEmergency: body.isEmergency ?? false,
      );
    });

    c.client.value = _fakeClient;
    c.step.value = 3;
    c.dob.value = DateTime(2015, 1, 1);
    c.representativeSaved.value = true;
    c.savedRepresentativeContact.value = ClientContactOut(
      id: 'rep-1',
      tenantId: 'tenant-1',
      clientId: 'client-1',
      name: 'Old Name',
      phone: '+61400000001',
      relationship: 'mother',
      legalRole: OnboardingKeys.relChildRepresentative,
      isPrimary: false,
      notifyVisitComplete: false,
      isEmergency: false,
    );
    c.contactsCreated.add(c.savedRepresentativeContact.value!);

    c.beginEditRepresentative();
    c.contactNameCtrl.text = 'Updated Rep';
    c.contactPhoneCtrl.text = '+61400000999';
    c.contactRelationshipPreset.value = 'mother';

    expect(await c.saveContactDraft(), isTrue);
    verify(() => mock.patchContact('client-1', 'rep-1', any())).called(1);
    verifyNever(() => mock.createContact(any(), any()));
    expect(c.savedRepresentativeContact.value?.name, 'Updated Rep');
    expect(c.representativeEditing.value, isFalse);
  });

  test(
    'saveContactDraft sends custom relationship for Other free-text',
    () async {
      ClientContactWriteRequest? captured;
      when(() => mock.createContact(any(), any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[1] as ClientContactWriteRequest;
        return ClientContactOut(
          id: 'c-custom',
          tenantId: 'tenant-1',
          clientId: 'client-1',
          name: captured!.name,
          phone: captured!.phone,
          relationship: captured!.relationship,
          isPrimary: captured!.isPrimary ?? false,
          notifyVisitComplete: captured!.notifyVisitComplete ?? false,
          isEmergency: captured!.isEmergency ?? false,
        );
      });

      c.client.value = _fakeClient;
      c.contactNameCtrl.text = 'Alex Cousin';
      c.contactPhoneCtrl.text = '+61400000022';
      c.contactRelationshipPreset.value = ContactFormHost.relationshipOtherKey;
      c.contactRelationshipOtherCtrl.text = 'Cousin';
      c.contactIsEmergency.value = true;

      expect(await c.saveContactDraft(), isTrue);
      expect(captured!.relationship, 'Cousin');
      expect(captured!.relationship, isNot('other'));
    },
  );

  test('saveContactDraft rejects Other without free-text', () async {
    c.client.value = _fakeClient;
    c.contactNameCtrl.text = 'Alex';
    c.contactPhoneCtrl.text = '+61400000022';
    c.contactRelationshipPreset.value = ContactFormHost.relationshipOtherKey;

    expect(await c.saveContactDraft(), isFalse);
    expect(c.errorMessage.value, contains('Specify the relationship'));
    verifyNever(() => mock.createContact(any(), any()));
  });

  test('saveContactDraft sends kinship mother with isEmergency', () async {
    ClientContactWriteRequest? captured;
    when(() => mock.createContact(any(), any())).thenAnswer((inv) async {
      captured = inv.positionalArguments[1] as ClientContactWriteRequest;
      return ClientContactOut(
        id: 'c-mother',
        tenantId: 'tenant-1',
        clientId: 'client-1',
        name: captured!.name,
        phone: captured!.phone,
        relationship: captured!.relationship,
        isPrimary: captured!.isPrimary ?? false,
        notifyVisitComplete: captured!.notifyVisitComplete ?? false,
        isEmergency: captured!.isEmergency ?? false,
      );
    });

    c.client.value = _fakeClient;
    c.contactNameCtrl.text = 'Jane Mother';
    c.contactPhoneCtrl.text = '+61400000011';
    c.contactRelationshipPreset.value = 'mother';
    c.contactIsEmergency.value = true;

    expect(await c.saveContactDraft(), isTrue);
    expect(captured!.relationship, 'mother');
    expect(captured!.isEmergency, isTrue);
    expect(c.emergencySaved.value, isTrue);
  });

  test('submitContacts advances with non-emergency contact only', () async {
    c.client.value = _fakeClient;
    c.step.value = 3;
    c.dob.value = DateTime(1990, 1, 1);
    c.contactDraftMode.value = 'nominee';
    c.contactsCreated.add(
      const ClientContactOut(
        id: 'c-friend',
        tenantId: 'tenant-1',
        clientId: 'client-1',
        name: 'Alex Friend',
        relationship: 'friend',
        isPrimary: false,
        notifyVisitComplete: false,
      ),
    );
    expect(await c.submitContactsStep(), isTrue);
    expect(c.step.value, 4);
  });

  test(
    'nominee also-emergency creates one contact with role and flag',
    () async {
      ClientContactWriteRequest? captured;
      when(() => mock.createContact(any(), any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[1] as ClientContactWriteRequest;
        return ClientContactOut(
          id: 'c-nom',
          tenantId: 'tenant-1',
          clientId: 'client-1',
          name: captured!.name,
          phone: captured!.phone,
          relationship: captured!.relationship,
          legalRole: captured!.legalRole,
          isPrimary: captured!.isPrimary ?? false,
          notifyVisitComplete: captured!.notifyVisitComplete ?? false,
          isEmergency: captured!.isEmergency ?? false,
        );
      });

      c.client.value = _fakeClient;
      c.dob.value = DateTime(2000, 1, 1);
      c.step.value = 3;
      c.contactDraftMode.value = 'nominee';
      c.contactNameCtrl.text = 'Pat Nominee';
      c.contactPhoneCtrl.text = '+61400000033';
      c.contactRelationshipPreset.value = 'mother';
      c.contactIsEmergency.value = true;

      expect(await c.saveContactDraft(), isTrue);
      expect(captured!.relationship, 'mother');
      expect(captured!.legalRole, OnboardingKeys.relNominee);
      expect(captured!.isEmergency, isTrue);
      expect(c.representativeSaved.value, isTrue);
    },
  );

  test('useExistingAsEmergency patches isEmergency true', () async {
    when(() => mock.patchContact(any(), any(), any())).thenAnswer((inv) async {
      final body = inv.positionalArguments[2] as ClientContactWriteRequest;
      return ClientContactOut(
        id: 'c-existing',
        tenantId: 'tenant-1',
        clientId: 'client-1',
        name: 'Jane Mother',
        relationship: 'mother',
        isPrimary: false,
        notifyVisitComplete: false,
        isEmergency: body.isEmergency ?? false,
      );
    });

    c.client.value = _fakeClient;
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

    expect(await c.useExistingAsEmergency('c-existing'), isTrue);
    final body =
        verify(
              () => mock.patchContact('client-1', 'c-existing', captureAny()),
            ).captured.single
            as ClientContactWriteRequest;
    expect(body.isEmergency, isTrue);
    expect(body.toJson().containsKey('is_primary'), isFalse);
    expect(c.contactsCreated.single.isEmergency, isTrue);
    expect(c.emergencySaved.value, isTrue);
  });

  test('carer kinship does not lock a legal representative role', () async {
    when(() => mock.createContact(any(), any())).thenAnswer((inv) async {
      final body = inv.positionalArguments[1] as ClientContactWriteRequest;
      return ClientContactOut(
        id: 'c-carer',
        tenantId: 'tenant-1',
        clientId: 'client-1',
        name: body.name,
        phone: body.phone,
        relationship: body.relationship,
        isPrimary: body.isPrimary ?? false,
        notifyVisitComplete: body.notifyVisitComplete ?? false,
        isEmergency: body.isEmergency ?? false,
      );
    });

    c.client.value = _fakeClient;
    c.contactNameCtrl.text = 'Kim Carer';
    c.contactPhoneCtrl.text = '+61400000044';
    c.contactRelationshipPreset.value = OnboardingKeys.relCarer;
    c.contactIsEmergency.value = true;

    expect(await c.saveContactDraft(), isTrue);
    expect(c.carerSaved.value, isTrue);
    expect(c.emergencySaved.value, isTrue);
    expect(c.representativeSaved.value, isFalse);
  });

  test('submitRepresentative blocks under-18 without child rep', () async {
    c.client.value = _fakeClient;
    c.dob.value = DateTime(2015, 1, 1);
    c.step.value = 3;
    c.contactDraftMode.value = 'representative';
    expect(await c.submitRepresentative(), isFalse);
    expect(c.errorMessage.value, contains('representative'));
  });

  test('submitRepresentative allows adult to skip nominee', () async {
    c.client.value = _fakeClient;
    c.dob.value = DateTime(2000, 1, 1);
    c.step.value = 3;
    c.contactDraftMode.value = 'nominee';
    expect(await c.submitRepresentative(), isTrue);
    expect(c.nomineeSkipped.value, isTrue);
    expect(c.step.value, 3);
  });

  test('submitContactsStep advances adult past empty Contacts', () async {
    c.client.value = _fakeClient;
    c.dob.value = DateTime(2000, 1, 1);
    c.step.value = 3;
    c.contactDraftMode.value = 'nominee';
    expect(await c.submitContactsStep(), isTrue);
    expect(c.nomineeSkipped.value, isTrue);
    expect(c.step.value, 4);
  });

  test('submitContactsStep blocks child without representative', () async {
    c.client.value = _fakeClient;
    c.dob.value = DateTime(2015, 1, 1);
    c.step.value = 3;
    c.contactDraftMode.value = 'representative';
    expect(await c.submitContactsStep(), isFalse);
    expect(c.errorMessage.value, contains('representative'));
    expect(c.step.value, 3);
  });

  test(
    'markConsentComplete fetches legal doc with patient.consent_agreement',
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
      when(
        () => mock.acceptClientLegal(any(), any(), any()),
      ).thenAnswer((_) async {});

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
        () =>
            mock.getLegalDocumentCurrent(OnboardingKeys.consentAgreementDocKey),
      ).called(1);
      verify(
        () => mock.acceptClientLegal(
          'client-1',
          OnboardingKeys.consentAgreement,
          any(),
        ),
      ).called(1);
    },
  );

  test(
    'markConsentComplete shows friendly message when legal doc missing',
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
    },
  );

  test(
    'upload fails closed without documents.upload / clients.docs.manage',
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
      when(
        () => mock.upsertProfileFact(any(), any(), any()),
      ).thenAnswer((_) async {});

      c.fullName.text = 'Sam';
      c.email.text = 'sam@example.com';
      c.phone.text = '+61411111111';
      c.dob.value = DateTime(1990, 1, 1);

      expect(await c.submitIdentity(), isFalse);
      expect(c.errorMessage.value, contains('documents.upload'));
      verifyNever(
        () => pipeline.uploadEvidence(
          request: any(named: 'request'),
          bytes: any(named: 'bytes'),
        ),
      );
    },
  );

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

  test('hydrateFromClient clears prior step state from previous session', () {
    c.emergencySaved.value = true;
    c.carerSaved.value = true;
    c.contactsCreated.add(
      const ClientContactOut(
        id: 'contact-1',
        tenantId: 'tenant-1',
        clientId: 'client-1',
        isPrimary: true,
        notifyVisitComplete: false,
        name: 'Emergency Contact',
        relationship: OnboardingKeys.relEmergency,
      ),
    );
    c.planStartDate.value = DateTime(2025, 6, 1);
    c.planEndDate.value = DateTime(2026, 6, 1);
    c.primarySiteSaved.value = true;
    c.representativeSaved.value = true;
    c.consentComplete.value = true;
    c.step.value = 4;

    c.hydrateFromClient(_fakeClient);

    expect(c.emergencySaved.value, isFalse);
    expect(c.carerSaved.value, isFalse);
    expect(c.contactsCreated, isEmpty);
    expect(c.planStartDate.value, isNull);
    expect(c.planEndDate.value, isNull);
    expect(c.primarySiteSaved.value, isFalse);
    expect(c.representativeSaved.value, isFalse);
    expect(c.consentComplete.value, isFalse);
    expect(c.fullName.text, 'Sam Parent');
    expect(c.step.value, 0);
  });

  test('submitIdentity after hydrate patches instead of creates', () async {
    when(
      () => mock.patchClient(any(), any()),
    ).thenAnswer((_) async => _fakeClient);
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async {});

    c.hydrateFromClient(_fakeClient);
    c.dob.value = DateTime(1990, 5, 1);

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

  group('referral Other (CR5)', () {
    test('hydrateReferral maps custom text to Other preset', () {
      final hydrated = OnboardingIdentityStep.hydrateReferral(
        'Community Centre',
      );
      expect(hydrated.preset, OnboardingIdentityStep.otherPresetKey);
      expect(hydrated.otherText, 'Community Centre');
    });

    test('hydrateReferral keeps known presets', () {
      final hydrated = OnboardingIdentityStep.hydrateReferral('NDIS');
      expect(hydrated.preset, OnboardingIdentityStep.otherPresetKey);
      expect(hydrated.otherText, 'NDIS');
    });

    test('submitIdentity rejects referral Other without free-text', () async {
      when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);

      _fillValidIdentity(c);
      c.referralSource.value = OnboardingIdentityStep.otherPresetKey;

      expect(await c.submitIdentity(), isFalse);
      expect(c.errorMessage.value, contains('referral'));
      verifyNever(() => mock.upsertProfileFact(any(), any(), any()));
    });

    test('submitIdentity saves typed referral string for Other', () async {
      ProfileFactUpsert? captured;
      when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
      when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((
        inv,
      ) async {
        final key = inv.positionalArguments[1] as String;
        if (key == OnboardingKeys.referralSource) {
          captured = inv.positionalArguments[2] as ProfileFactUpsert;
        }
      });

      _fillValidIdentity(c);
      c.referralSource.value = OnboardingIdentityStep.otherPresetKey;
      c.referralOtherCtrl.text = 'Community Centre';

      expect(await c.submitIdentity(), isTrue);
      expect(captured?.valueJson, 'Community Centre');
      expect(captured?.valueJson, isNot('Other'));
    });
  });

  group('sex Other (CR5)', () {
    test('hydrateSexGender maps custom text to Other preset', () {
      final hydrated = OnboardingIdentityStep.hydrateSexGender('Agender');
      expect(hydrated.preset, OnboardingIdentityStep.otherPresetKey);
      expect(hydrated.otherText, 'Agender');
    });

    test('hydrateSexGender keeps known presets', () {
      final hydrated = OnboardingIdentityStep.hydrateSexGender('Non-binary');
      expect(hydrated.preset, 'Non-binary');
      expect(hydrated.otherText, isEmpty);
    });

    test('submitIdentity rejects sex Other without free-text', () async {
      when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);

      _fillValidIdentity(c);
      c.sexGender.value = OnboardingIdentityStep.otherPresetKey;

      expect(await c.submitIdentity(), isFalse);
      expect(c.errorMessage.value, contains('sex'));
      verifyNever(() => mock.upsertProfileFact(any(), any(), any()));
    });

    test('submitIdentity saves typed sex string for Other', () async {
      ProfileFactUpsert? captured;
      when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
      when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((
        inv,
      ) async {
        final key = inv.positionalArguments[1] as String;
        if (key == OnboardingKeys.sexGender) {
          captured = inv.positionalArguments[2] as ProfileFactUpsert;
        }
      });

      _fillValidIdentity(c);
      c.sexGender.value = OnboardingIdentityStep.otherPresetKey;
      c.sexGenderOtherCtrl.text = 'Agender';

      expect(await c.submitIdentity(), isTrue);
      expect(captured?.valueJson, 'Agender');
      expect(captured?.valueJson, isNot('Other'));
    });
  });

  test('submitIdentity uploads optional identity card attachments', () async {
    final pipeline = _MockDocumentPipeline();
    when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer(
      (_) async => const DocumentOut(
        id: 'doc-companion',
        ownerType: 'client',
        ownerId: 'client-1',
        filename: 'companion.pdf',
        contentType: 'application/pdf',
        sizeBytes: 3,
        scanStatus: 'clean',
        category: 'companion_card',
      ),
    );

    c.dispose();
    c = _buildController(
      documentPipeline: pipeline,
      pickCardFile:
          () async => const PendingIdentityCardFile(
            name: 'companion.pdf',
            bytes: [1, 2, 3],
            contentType: 'application/pdf',
          ),
    );

    _fillValidIdentity(c);
    c.companionCardAttachment.pending.value = const PendingIdentityCardFile(
      name: 'companion.pdf',
      bytes: [1, 2, 3],
      contentType: 'application/pdf',
    );

    expect(await c.submitIdentity(), isTrue);
    verify(
      () => mock.upsertProfileFact(
        'client-1',
        OnboardingKeys.companionCard,
        any(
          that: predicate<ProfileFactUpsert>(
            (upsert) => upsert.documentId == 'doc-companion',
          ),
        ),
      ),
    ).called(1);
  });

  test('hydrateIdentityFromFacts restores card document ids', () {
    c.hydrateIdentityFromFacts([
      const ClientProfileFactOut(
        requirementKey: OnboardingKeys.pensionCard,
        documentId: 'doc-pension-1',
      ),
    ]);

    expect(c.pensionCardAttachment.existingDocumentId.value, 'doc-pension-1');
    expect(c.pensionCardAttachment.existingDocumentLabel.value, isNotEmpty);
  });

  test(
    'hydrateIdentityFromFacts maps unknown referral and sex to Other + text',
    () {
      c.hydrateIdentityFromFacts([
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.referralSource,
          valueJson: 'Community Centre',
        ),
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.sexGender,
          valueJson: 'Agender',
        ),
      ]);

      expect(c.referralSource.value, OnboardingIdentityStep.otherPresetKey);
      expect(c.referralOtherCtrl.text, 'Community Centre');
      expect(c.sexGender.value, OnboardingIdentityStep.otherPresetKey);
      expect(c.sexGenderOtherCtrl.text, 'Agender');
    },
  );

  test(
    'hydrateSupportPlanFromFacts restores NDIS and legacy Other fallback',
    () {
      c.hydrateSupportPlanFromFacts([
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.ndis,
          valueJson: '431234567',
          documentId: 'doc-ndis-1',
        ),
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.fundingNotToExceed,
          valueJson: '5000',
        ),
      ]);

      expect(c.ndisCtrl.text, '431234567');
      expect(c.ndisPdfAttachment.existingDocumentId.value, 'doc-ndis-1');
      expect(c.supportPlanOtherCtrl.text, '5000');
    },
  );

  test(
    'hydrateSupportPlanFromFacts prefers support_plan_other over legacy',
    () {
      c.hydrateSupportPlanFromFacts([
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.supportPlanOther,
          valueJson: 'Custom note',
        ),
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.fundingNotToExceed,
          valueJson: '5000',
        ),
      ]);

      expect(c.supportPlanOtherCtrl.text, 'Custom note');
    },
  );

  test(
    'submitPreferences requires interpreter language when interpreter on',
    () async {
      c.client.value = _fakeClient;
      c.step.value = 2;
      c.interpreterRequired.value = true;
      expect(await c.submitPreferences(), isFalse);
      expect(c.errorMessage.value, contains('interpreter language'));

      when(
        () => mock.upsertProfileFact(any(), any(), any()),
      ).thenAnswer((_) async {});
      c.interpreterLanguageCtrl.text = 'Arabic';
      expect(await c.submitPreferences(), isTrue);
      verify(
        () => mock.upsertProfileFact(
          'client-1',
          OnboardingKeys.interpreterLanguage,
          any(),
        ),
      ).called(1);
    },
  );

  test('addSupportSpecialist allows duplicate types and expands details', () {
    c.addSupportSpecialist(SupportPlanSpecialistTypes.speechTherapist);
    c.addSupportSpecialist(SupportPlanSpecialistTypes.speechTherapist);
    expect(c.supportSpecialists, hasLength(2));
    expect(c.supportSpecialists.every((e) => e.expanded.value), isTrue);
    c.clearSupportSpecialists();
  });

  test('coordinator step persists single SC specialist entry', () async {
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async {});
    c.client.value = _fakeClient;
    c.step.value = 6;
    c.supportCoordinatorEntry.fields.nameCtrl.text = 'Jane SC';

    expect(await c.submitSupportCoordinatorStep(soft: false), isTrue);
    expect(c.step.value, 7);

    final captured =
        verify(
              () => mock.upsertProfileFact(
                'client-1',
                OnboardingKeys.supportPlanSpecialists,
                captureAny(),
              ),
            ).captured.single
            as ProfileFactUpsert;
    final value = captured.valueJson as List;
    expect(value, hasLength(1));
    expect(value.first['type'], SupportPlanSpecialistTypes.supportCoordinator);
    expect(value.first['name'], 'Jane SC');
  });

  test('specialists step persists non-coordinator entries with SC merge', () async {
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async {});
    c.client.value = _fakeClient;
    c.step.value = 7;
    c.supportCoordinatorEntry.fields.nameCtrl.text = 'Jane SC';
    c.addSupportSpecialist(SupportPlanSpecialistTypes.speechTherapist);
    c.supportSpecialists.first.fields.nameCtrl.text = 'Alex OT';

    expect(await c.submitSupportSpecialistsStep(soft: false), isTrue);
    expect(c.step.value, 8);

    final captured =
        verify(
              () => mock.upsertProfileFact(
                'client-1',
                OnboardingKeys.supportPlanSpecialists,
                captureAny(),
              ),
            ).captured.single
            as ProfileFactUpsert;
    final value = captured.valueJson as List;
    expect(value, hasLength(2));
    expect(value.first['type'], SupportPlanSpecialistTypes.supportCoordinator);
    expect(value.last['type'], SupportPlanSpecialistTypes.speechTherapist);
    c.clearSupportSpecialists();
  });

  test(
    'soft-skip coordinator clears previously saved specialists fact',
    () async {
      when(
        () => mock.upsertProfileFact(any(), any(), any()),
      ).thenAnswer((_) async {});
      c.client.value = _fakeClient;
      c.hydrateSupportPlanFromFacts([
        ClientProfileFactOut(
          requirementKey: OnboardingKeys.supportPlanSpecialists,
          valueJson: [
            {
              'type': SupportPlanSpecialistTypes.supportCoordinator,
              'name': 'Jane SC',
            },
          ],
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      c.supportCoordinatorEntry.fields.nameCtrl.clear();
      c.step.value = 6;

      expect(await c.submitSupportCoordinatorStep(soft: true), isTrue);
      expect(c.step.value, 7);

      final captured =
          verify(
                () => mock.upsertProfileFact(
                  'client-1',
                  OnboardingKeys.supportPlanSpecialists,
                  captureAny(),
                ),
              ).captured.single
              as ProfileFactUpsert;
      expect(captured.clearValue, isTrue);
    },
  );

  test(
    'soft-skip specialists clears previously saved specialists fact',
    () async {
      when(
        () => mock.upsertProfileFact(any(), any(), any()),
      ).thenAnswer((_) async {});
      c.client.value = _fakeClient;
      c.hydrateSupportPlanFromFacts([
        ClientProfileFactOut(
          requirementKey: OnboardingKeys.supportPlanSpecialists,
          valueJson: [
            {
              'type': SupportPlanSpecialistTypes.supportCoordinator,
              'name': 'Jane SC',
            },
            {
              'type': SupportPlanSpecialistTypes.physiotherapist,
              'name': 'Bob PT',
            },
          ],
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      c.supportCoordinatorEntry.fields.nameCtrl.clear();
      c.clearSupportSpecialists();
      c.step.value = 7;

      expect(await c.submitSupportSpecialistsStep(soft: true), isTrue);
      expect(c.step.value, 8);

      final captured =
          verify(
                () => mock.upsertProfileFact(
                  'client-1',
                  OnboardingKeys.supportPlanSpecialists,
                  captureAny(),
                ),
              ).captured.single
              as ProfileFactUpsert;
      expect(captured.clearValue, isTrue);
    },
  );

  test('hydrate partitions SC into coordinator form', () {
    c.hydrateSupportPlanFromFacts([
      ClientProfileFactOut(
        requirementKey: OnboardingKeys.supportPlanSpecialists,
        valueJson: [
          {
            'type': SupportPlanSpecialistTypes.supportCoordinator,
            'name': 'Legacy SC',
          },
          {
            'type': SupportPlanSpecialistTypes.physiotherapist,
            'name': 'Bob PT',
          },
        ],
      ),
    ]);
    expect(c.supportCoordinatorEntry.fields.nameCtrl.text, 'Legacy SC');
    expect(c.supportSpecialists, hasLength(1));
    expect(
      c.supportSpecialists.first.type,
      SupportPlanSpecialistTypes.physiotherapist,
    );
    c.clearSupportSpecialists();
  });

  test('submitIdentity does not upsert allergies', () async {
    when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async {});
    _fillValidIdentity(c);
    c.allergiesCtrl.text = 'Peanuts';
    expect(await c.submitIdentity(), isTrue);
    verifyNever(
      () => mock.upsertProfileFact(
        any(),
        OnboardingKeys.allergies,
        any(),
      ),
    );
  });

  test('submitCarePlanStep upserts allergies fact', () async {
    when(
      () => mock.upsertProfileFact(any(), any(), any()),
    ).thenAnswer((_) async {});
    c.client.value = _fakeClient;
    c.step.value = 5;
    c.allergiesCtrl.text = 'Peanuts';
    expect(await c.submitCarePlanStep(soft: false), isTrue);
    expect(c.step.value, 6);
    verify(
      () => mock.upsertProfileFact(
        'client-1',
        OnboardingKeys.allergies,
        any(
          that: predicate<ProfileFactUpsert>((u) => u.valueJson == 'Peanuts'),
        ),
      ),
    ).called(1);
  });

  test(
    'soft-skip care plan clears previously saved consent and allergies',
    () async {
      when(
        () => mock.upsertProfileFact(any(), any(), any()),
      ).thenAnswer((_) async {});
      c.client.value = _fakeClient;
      c.hydrateIdentityFromFacts([
        ClientProfileFactOut(
          requirementKey: OnboardingKeys.allergies,
          valueJson: 'Peanuts',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      c.hydrateSupportPlanFromFacts([
        ClientProfileFactOut(
          requirementKey: OnboardingKeys.infoShareConsent,
          valueJson: true,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        ClientProfileFactOut(
          requirementKey: OnboardingKeys.specificSupportsConsent,
          valueJson: true,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        ClientProfileFactOut(
          requirementKey: OnboardingKeys.supportPlanOther,
          valueJson: 'Primary disability: ASD',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      c.allergiesCtrl.clear();
      c.supportPlanOtherCtrl.clear();
      c.primaryDisabilityCtrl.clear();
      c.infoShareConsent.value = false;
      c.specificSupportsConsent.value = false;
      c.step.value = 5;

      expect(await c.submitCarePlanStep(soft: true), isTrue);
      expect(c.step.value, 6);

      verify(
        () => mock.upsertProfileFact(
          'client-1',
          OnboardingKeys.allergies,
          any(that: predicate<ProfileFactUpsert>((u) => u.clearValue == true)),
        ),
      ).called(1);
      verify(
        () => mock.upsertProfileFact(
          'client-1',
          OnboardingKeys.supportPlanOther,
          any(that: predicate<ProfileFactUpsert>((u) => u.clearValue == true)),
        ),
      ).called(1);
      verify(
        () => mock.upsertProfileFact(
          'client-1',
          OnboardingKeys.infoShareConsent,
          any(
            that: predicate<ProfileFactUpsert>((u) => u.valueJson == false),
          ),
        ),
      ).called(1);
      verify(
        () => mock.upsertProfileFact(
          'client-1',
          OnboardingKeys.specificSupportsConsent,
          any(
            that: predicate<ProfileFactUpsert>((u) => u.valueJson == false),
          ),
        ),
      ).called(1);
      // Never-hydrated clinical store must not clobber Care-tab flags.
      verifyNever(
        () => mock.upsertProfileFact(
          'client-1',
          ClinicalKeys.bspOnFile,
          any(),
        ),
      );
    },
  );

  test(
    'care plan soft-skip persists clinical flags only after hydrate',
    () async {
      when(
        () => mock.upsertProfileFact(any(), any(), any()),
      ).thenAnswer((_) async {});
      c.client.value = _fakeClient;
      c.clinical.hasHydrated = true;
      c.clinical.bspOnFile.value = false;
      c.step.value = 5;

      expect(await c.submitCarePlanStep(soft: true), isTrue);

      verify(
        () => mock.upsertProfileFact(
          'client-1',
          ClinicalKeys.bspOnFile,
          any(
            that: predicate<ProfileFactUpsert>((u) => u.valueJson == false),
          ),
        ),
      ).called(1);
    },
  );

  test('submitSupportPlan rejects invalid budget values', () async {
    c.client.value = _fakeClient;
    c.step.value = 4;
    c.ndisCtrl.text = '431234567';
    c.planManagementType.value = 'self_managed';
    c.budgetCoreCtrl.text = 'abc';
    expect(await c.submitSupportPlan(), isFalse);
    expect(c.budgetFieldError.value, contains('dollar amounts'));
  });

  test(
    'previousStep from NDIS returns to Contacts',
    () {
      c.step.value = 4;
      c.contactDraftMode.value = 'nominee';
      c.contactRelationshipPreset.value = 'mother';
      c.previousStep();
      expect(c.step.value, 3);
      expect(c.contactDraftMode.value, 'nominee');
      expect(c.contactRelationshipPreset.value, 'mother');
    },
  );

  test('legal upload flags are independent per document', () async {
    c.client.value = _fakeClient;
    c.consentUploading.value = true;
    c.serviceAgreementUploading.value = false;
    expect(c.consentUploading.value, isTrue);
    expect(c.serviceAgreementUploading.value, isFalse);
  });

  test('submitIdentity persists companion and pension card numbers', () async {
    final captured = <String, ProfileFactUpsert>{};
    when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((
      inv,
    ) async {
      captured[inv.positionalArguments[1] as String] =
          inv.positionalArguments[2] as ProfileFactUpsert;
    });

    _fillValidIdentity(c);
    c.companionCardNumberCtrl.text = 'CC-123';
    c.pensionCardNumberCtrl.text = 'PC-456';

    expect(await c.submitIdentity(), isTrue);
    expect(captured[OnboardingKeys.companionCard]?.valueJson, 'CC-123');
    expect(captured[OnboardingKeys.pensionCard]?.valueJson, 'PC-456');
  });

  test('persist identity cards writes disability_card value_json', () async {
    final captured = <String, ProfileFactUpsert>{};
    when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((
      inv,
    ) async {
      captured[inv.positionalArguments[1] as String] =
          inv.positionalArguments[2] as ProfileFactUpsert;
    });

    _fillValidIdentity(c);
    c.disabilityCardNumberCtrl.text = 'DC-99';

    expect(await c.submitIdentity(), isTrue);
    expect(captured[OnboardingKeys.disabilityCard]?.valueJson, 'DC-99');
  });

  test('hydrate restores disability card number from fact', () {
    c.hydrateIdentityFromFacts([
      const ClientProfileFactOut(
        requirementKey: OnboardingKeys.disabilityCard,
        valueJson: 'DC-1',
      ),
    ]);

    expect(c.disabilityCardNumberCtrl.text, 'DC-1');
  });

  test('submitIdentity persists photo_id number as plain text', () async {
    ProfileFactUpsert? photoFact;
    when(() => mock.createClient(any())).thenAnswer((_) async => _fakeClient);
    when(() => mock.upsertProfileFact(any(), any(), any())).thenAnswer((
      inv,
    ) async {
      final key = inv.positionalArguments[1] as String;
      if (key == OnboardingKeys.photoId) {
        photoFact = inv.positionalArguments[2] as ProfileFactUpsert;
      }
    });

    _fillValidIdentity(c);
    c.photoIdNumberCtrl.text = 'P1234567';

    expect(await c.submitIdentity(), isTrue);
    expect(photoFact?.valueJson, 'P1234567');
  });

  test(
    'hydrateIdentityFromFacts restores photo_id number from legacy JSON',
    () {
      c.hydrateIdentityFromFacts([
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.photoId,
          valueJson: '{"number":"P99","id_type":"Photo card"}',
        ),
      ]);

      expect(c.photoIdNumberCtrl.text, 'P99');
    },
  );

  test('saveExistingContactAsRepresentative patches legal_role', () async {
    when(() => mock.patchContact(any(), any(), any())).thenAnswer((inv) async {
      final body = inv.positionalArguments[2] as ClientContactWriteRequest;
      return ClientContactOut(
        id: 'c-mother',
        tenantId: 'tenant-1',
        clientId: 'client-1',
        name: 'Jane Mother',
        relationship: 'mother',
        legalRole: body.legalRole,
        isPrimary: false,
        notifyVisitComplete: false,
        isEmergency: true,
      );
    });

    c.client.value = _fakeClient;
    c.dob.value = DateTime(2015, 1, 1);
    c.step.value = 3;
    c.contactDraftMode.value = 'representative';
    c.reuseEmergencyContactId.value = 'c-mother';
    c.contactsCreated.add(
      const ClientContactOut(
        id: 'c-mother',
        tenantId: 'tenant-1',
        clientId: 'client-1',
        name: 'Jane Mother',
        relationship: 'mother',
        isPrimary: false,
        notifyVisitComplete: false,
        isEmergency: true,
      ),
    );

    expect(await c.saveExistingContactAsRepresentative(), isTrue);
    expect(c.representativeSaved.value, isTrue);
    final body =
        verify(
              () => mock.patchContact('client-1', 'c-mother', captureAny()),
            ).captured.single
            as ClientContactWriteRequest;
    expect(body.legalRole, OnboardingKeys.relChildRepresentative);
  });

  test('siteNameCtrl is empty on init (no default Home)', () {
    expect(c.siteNameCtrl.text, isEmpty);
  });

  test('resetForResume clears siteNameCtrl', () {
    c.siteNameCtrl.text = 'Home';
    c.resetForResume();
    expect(c.siteNameCtrl.text, isEmpty);
  });

  test('addLegalOtherDoc appends other-type row with unique id', () {
    c.addLegalOtherDoc();
    c.addLegalOtherDoc();
    expect(c.legalOtherDocs, hasLength(2));
    expect(c.legalOtherDocs.every((e) => e.typeKey == 'other'), isTrue);
    expect(c.legalOtherDocs[0].id, isNot(equals(c.legalOtherDocs[1].id)));
    expect(c.legalOtherDocs[0].id, startsWith('legal-other-'));
  });

  test('removeLegalOtherDoc removes matching row', () {
    c.addLegalOtherDoc();
    final id = c.legalOtherDocs.single.id;
    c.removeLegalOtherDoc(id);
    expect(c.legalOtherDocs, isEmpty);
  });

  test('resetForResume clears legalOtherDocs', () {
    c.addLegalOtherDoc();
    c.resetForResume();
    expect(c.legalOtherDocs, isEmpty);
  });

  test(
    'uploadLegalOther marks row complete and stores document id',
    () async {
      final pipeline = _MockDocumentPipeline();
      when(
        () => pipeline.uploadEvidence(
          request: any(named: 'request'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer(
        (_) async => const DocumentOut(
          id: 'doc-1',
          ownerType: 'client',
          ownerId: 'client-1',
          filename: 'order.pdf',
          contentType: 'application/pdf',
          sizeBytes: 3,
          scanStatus: 'clean',
        ),
      );

      c.dispose();
      c = _buildController(documentPipeline: pipeline);
      c.client.value = _fakeClient;
      c.addLegalOtherDoc();
      c.legalOtherDocs.first.typeKey = 'court_order';

      expect(
        await c.uploadLegalOther(
          c.legalOtherDocs.first.id,
          [1, 2, 3],
          'order.pdf',
        ),
        isTrue,
      );
      expect(c.legalOtherDocs.first.complete, isTrue);
      expect(c.legalOtherDocs.first.documentId, 'doc-1');
      final request =
          verify(
                () => pipeline.uploadEvidence(
                  request: captureAny(named: 'request'),
                  bytes: any(named: 'bytes'),
                ),
              ).captured.single
              as UploadUrlRequest;
      expect(request.category, OnboardingKeys.legalOtherCategory);
    },
  );

  test('finishOnboarding succeeds with zero other legal docs', () async {
    when(() => mock.getClient('client-1')).thenAnswer((_) async => _fakeClient);
    when(() => mock.patchClient(any(), any())).thenAnswer((_) async {
      return ClientOut(
        id: _fakeClient.id,
        tenantId: _fakeClient.tenantId,
        fullName: _fakeClient.fullName,
        status: _fakeClient.status,
        metadata: const {'onboarding_incomplete': false},
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
    c.consentComplete.value = true;
    c.serviceAgreementComplete.value = true;
    expect(c.legalOtherDocs, isEmpty);

    expect(await c.finishOnboarding(), isTrue);
    verifyNever(
      () => mock.upsertProfileFact(
        any(),
        OnboardingKeys.legalOtherDocuments,
        any(),
      ),
    );
  });

  test('Other label longer than 120 chars is rejected', () async {
    final pipeline = _MockDocumentPipeline();
    c.dispose();
    c = _buildController(documentPipeline: pipeline);
    c.client.value = _fakeClient;
    c.addLegalOtherDoc();
    c.legalOtherDocs.first.typeKey = 'other';
    c.legalOtherDocs.first.customLabel =
        'x' * (legalOtherMaxCustomLabelLength + 1);

    expect(
      await c.uploadLegalOther(
        c.legalOtherDocs.first.id,
        [1],
        'order.pdf',
      ),
      isFalse,
    );
    expect(c.legalOtherDocs.first.complete, isFalse);
    expect(c.errorMessage.value, contains('120'));
    verifyNever(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    );
  });

  test('upload rejected when displayLabel null', () async {
    final pipeline = _MockDocumentPipeline();
    c.dispose();
    c = _buildController(documentPipeline: pipeline);
    c.client.value = _fakeClient;
    c.addLegalOtherDoc();
    // typeKey defaults to 'other' with empty customLabel → null displayLabel
    expect(c.legalOtherDocs.first.displayLabel, isNull);

    expect(
      await c.uploadLegalOther(
        c.legalOtherDocs.first.id,
        [1],
        'order.pdf',
      ),
      isFalse,
    );
    expect(c.legalOtherDocs.first.complete, isFalse);
    expect(c.errorMessage.value, contains('name'));
    verifyNever(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    );
  });

  test(
    'finishOnboarding upserts legal_other_documents from complete rows',
    () async {
      when(
        () => mock.getClient('client-1'),
      ).thenAnswer((_) async => _fakeClient);
      when(() => mock.patchClient(any(), any())).thenAnswer((_) async {
        return ClientOut(
          id: _fakeClient.id,
          tenantId: _fakeClient.tenantId,
          fullName: _fakeClient.fullName,
          status: _fakeClient.status,
          metadata: const {'onboarding_incomplete': false},
          createdAt: _now,
          updatedAt: _now,
        );
      });
      when(
        () => mock.upsertProfileFact(any(), any(), any()),
      ).thenAnswer((_) async {});

      c.dispose();
      c = _buildController(
        softGateConfirm: (_) async => true,
        onFinished: (_) {},
      );
      c.client.value = _fakeClient;
      c.consentComplete.value = true;
      c.serviceAgreementComplete.value = true;
      c.legalOtherDocs.add(
        LegalOtherDocumentDraft(
          id: 'lo-1',
          typeKey: 'court_order',
          documentId: 'doc-court',
          complete: true,
        ),
      );
      c.legalOtherDocs.add(
        LegalOtherDocumentDraft(
          id: 'lo-2',
          typeKey: 'other',
          customLabel: 'Custom',
          // incomplete — excluded from fact
        ),
      );

      expect(await c.finishOnboarding(), isTrue);
      final upsert =
          verify(
                () => mock.upsertProfileFact(
                  'client-1',
                  OnboardingKeys.legalOtherDocuments,
                  captureAny(),
                ),
              ).captured.single
              as ProfileFactUpsert;
      expect(upsert.valueJson, [
        {
          'type': 'court_order',
          'label': 'Court order',
          'document_id': 'doc-court',
        },
      ]);
    },
  );

  test('hydrateLegalOtherFromFacts restores complete rows', () {
    c.hydrateLegalOtherFromFacts([
      const ClientProfileFactOut(
        requirementKey: OnboardingKeys.legalOtherDocuments,
        valueJson: [
          {
            'type': 'power_of_attorney',
            'label': 'Power of attorney',
            'document_id': 'doc-poa',
          },
        ],
      ),
    ]);
    expect(c.legalOtherDocs, hasLength(1));
    expect(c.legalOtherDocs.first.typeKey, 'power_of_attorney');
    expect(c.legalOtherDocs.first.documentId, 'doc-poa');
    expect(c.legalOtherDocs.first.complete, isTrue);
  });
}
