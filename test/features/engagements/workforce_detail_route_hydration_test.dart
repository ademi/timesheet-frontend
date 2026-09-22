import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/engagements/controllers/workforce_controller.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/models/staff_contractor_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 9, 22, 9);

final _engagement = EngagementOut(
  id: 'eng-1',
  tenantId: 'tenant-1',
  contractorId: 'contractor-1',
  contractorName: 'Demo Contractor',
  contractorEmail: 'contractor@demotenant.example',
  status: 'active',
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockEngagementsRepository repository;
  late _MockCredentialsRepository credentials;
  late _MockSessionService session;
  late WorkforceController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    repository = _MockEngagementsRepository();
    credentials = _MockCredentialsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => repository.listTenantEngagements(),
    ).thenAnswer((_) async => [_engagement]);
    when(
      () => repository.listPendingContractorInvites(),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getContractorProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    when(
      () => repository.getStaffContractor(any()),
    ).thenAnswer(
      (_) async => const StaffContractorOut(
        id: 'contractor-1',
        userId: 'user-1',
        fullName: 'Demo Contractor',
        email: 'contractor@demotenant.example',
      ),
    );
    controller = WorkforceController(
      repository: repository,
      credentialsRepository: credentials,
      session: session,
    );
  });

  tearDown(Get.reset);

  test('ensureDetailHydratedFromRoute loads by parameters id', () async {
    when(
      () => repository.listTenantEngagements(),
    ).thenAnswer((_) async => [_engagement]);
    Get.parameters['id'] = _engagement.id;
    Get.routing.args = null;

    await controller.load();
    await controller.ensureDetailHydratedFromRoute();

    expect(controller.selected?.id, _engagement.id);
    expect(controller.selectedRx.value?.id, _engagement.id);
  });

  test('ensureDetailHydratedFromRoute uses Get.arguments EngagementOut', () async {
    Get.routing.args = _engagement;
    Get.parameters.clear();

    await controller.ensureDetailHydratedFromRoute();

    expect(controller.selected?.id, _engagement.id);
  });

  testWidgets('openDetail passes id in route parameters', (tester) async {
    Get.put(controller);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.staffWorkforce,
        getPages: [
          GetPage(
            name: AppRoutes.staffWorkforce,
            page: () => const SizedBox.shrink(),
          ),
          GetPage(
            name: AppRoutes.staffWorkforceDetail,
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    controller.openDetail(_engagement);
    await tester.pumpAndSettle();

    expect(Get.parameters['id'], _engagement.id);
    expect(controller.selected?.id, _engagement.id);
  });
}
