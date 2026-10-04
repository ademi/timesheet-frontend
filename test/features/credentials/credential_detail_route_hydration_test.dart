import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/credentials/controllers/credentials_controller.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 9, 22, 9);

final _credential = CredentialOut(
  id: 'cred-1',
  contractorId: 'contractor-1',
  credentialType: 'wwcc',
  status: 'approved',
  evidencePresence: 'present',
  provenanceState: 'contractor_asserted',
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockCredentialsRepository repository;
  late _MockDocumentPipeline pipeline;
  late _MockComplianceRepository compliance;
  late _MockSessionService session;
  late CredentialsController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    repository = _MockCredentialsRepository();
    pipeline = _MockDocumentPipeline();
    compliance = _MockComplianceRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.contractorId).thenReturn(RxnString('contractor-1'));
    when(() => session.claims).thenReturn(null);
    when(() => repository.listMine()).thenAnswer((_) async => [_credential]);
    when(
      () => repository.listCredentialCategories(),
    ).thenAnswer((_) async => []);
    when(
      () => pipeline.listEvidenceForContractor(any()),
    ).thenAnswer((_) async => []);
    controller = CredentialsController(
      repository: repository,
      documentPipeline: pipeline,
      complianceRepository: compliance,
      session: session,
    );
  });

  tearDown(Get.reset);

  test('ensureDetailHydratedFromRoute loads by parameters id', () async {
    Get.parameters['id'] = _credential.id;
    Get.routing.args = null;

    await controller.load();
    await controller.ensureDetailHydratedFromRoute();

    expect(controller.selected?.id, _credential.id);
  });

  test('ensureDetailHydratedFromRoute uses Get.arguments CredentialOut', () async {
    Get.routing.args = _credential;
    Get.parameters.clear();

    await controller.ensureDetailHydratedFromRoute();

    expect(controller.selected?.id, _credential.id);
  });

  testWidgets('openDetail passes id in route parameters', (tester) async {
    Get.put(controller);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.contractorCredentials,
        getPages: [
          GetPage(
            name: AppRoutes.contractorCredentials,
            page: () => const SizedBox.shrink(),
          ),
          GetPage(
            name: AppRoutes.contractorCredentialDetail,
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    controller.openDetail(_credential);
    await tester.pumpAndSettle();

    expect(Get.parameters['id'], _credential.id);
    expect(controller.selected?.id, _credential.id);
  });
}
