import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/credentials/controllers/credentials_controller.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/core/services/session_service.dart';

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late _MockCredentialsRepository repository;
  late _MockDocumentPipeline pipeline;
  late _MockComplianceRepository compliance;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    repository = _MockCredentialsRepository();
    pipeline = _MockDocumentPipeline();
    compliance = _MockComplianceRepository();
    session = _MockSessionService();

    when(
      () => session.hasPermission(AppPermissions.credentialsRead),
    ).thenReturn(true);
    when(
      () => session.hasPermission(AppPermissions.credentialsManage),
    ).thenReturn(true);
    when(
      () => session.hasPermission(AppPermissions.documentsUpload),
    ).thenReturn(true);
    when(() => session.contractorId).thenReturn(RxnString('contractor-1'));
    when(() => session.claims).thenReturn(null);
    when(() => repository.listMine()).thenAnswer((_) async => []);
    when(
      () => repository.listCredentialCategories(),
    ).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  test('hasCleanEvidenceReady requires all evidence clean', () {
    final controller = CredentialsController(
      repository: repository,
      documentPipeline: pipeline,
      complianceRepository: compliance,
      session: session,
    );
    controller.selectedEvidence.add(
      const DocumentOut(
        id: 'd1',
        ownerType: 'contractor',
        ownerId: 'contractor-1',
        filename: 'a.pdf',
        contentType: 'application/pdf',
        sizeBytes: 1,
        scanStatus: 'pending',
      ),
    );
    expect(controller.hasSelectedEvidence, isTrue);
    expect(controller.hasCleanEvidenceReady, isFalse);
    expect(controller.hasPendingEvidenceScan, isTrue);
    expect(controller.isSaving.value, isFalse);

    controller.selectedEvidence[0] = controller.selectedEvidence.first.copyWith(
      scanStatus: 'clean',
    );
    controller.selectedEvidence.refresh();
    expect(controller.hasCleanEvidenceReady, isTrue);
    expect(controller.isUploadingEvidence.value, isFalse);
  });
}
