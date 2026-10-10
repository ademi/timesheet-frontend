import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/contractor_onboarding/data/models/compliance_models.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/credentials/controllers/credentials_controller.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late CredentialsController controller;
  late _MockCredentialsRepository repository;
  late _MockComplianceRepository compliance;
  late _MockSessionService session;

  setUpAll(() {
    registerFallbackValue(
      const LegalEventCreate(
        eventType: 'presented',
        presentationSource: 'test',
      ),
    );
    registerFallbackValue(
      const CredentialCreateRequest(
        credentialType: 'vehicle_registration',
        noticeEventId: 'n1',
        evidenceDocumentIds: ['d1'],
      ),
    );
  });

  setUp(() {
    Get.testMode = true;
    clearCredentialCategoryLabelCache();
    CredentialsController.pendingMissingCreateTypes = null;
    repository = _MockCredentialsRepository();
    final pipeline = _MockDocumentPipeline();
    compliance = _MockComplianceRepository();
    session = _MockSessionService();

    when(
      () => session.hasPermission(AppPermissions.credentialsRead),
    ).thenReturn(true);
    when(
      () => session.hasPermission(AppPermissions.credentialsManage),
    ).thenReturn(true);
    when(() => session.contractorId).thenReturn(RxnString('contractor-1'));
    when(() => session.claims).thenReturn(null);
    when(() => repository.listMine()).thenAnswer((_) async => []);
    when(
      () => repository.listCredentialCategories(),
    ).thenAnswer((_) async => []);

    controller = CredentialsController(
      repository: repository,
      documentPipeline: pipeline,
      complianceRepository: compliance,
      session: session,
    );
  });

  tearDown(() {
    CredentialsController.pendingMissingCreateTypes = null;
    Get.reset();
  });

  test('createMissingCredential returns null on notice failure (no success)',
      () async {
    controller.beginMissingCreate(['vehicle_registration', 'first_aid']);
    final draft = controller.missingDrafts['vehicle_registration']!;
    draft.selectedEvidence.add(
      const DocumentOut(
        id: 'doc-1',
        ownerType: 'contractor',
        ownerId: 'contractor-1',
        filename: 'drivers_licence.pdf',
        contentType: 'application/pdf',
        sizeBytes: 10,
        scanStatus: 'clean',
      ),
    );

    when(
      () => compliance.listCollectionNotices(
        credentialType: any(named: 'credentialType'),
        jurisdiction: any(named: 'jurisdiction'),
      ),
    ).thenAnswer((_) async => []);

    final result = await controller.createMissingCredential(
      'vehicle_registration',
    );

    expect(result, isNull);
    expect(
      draft.errorMessage.value,
      'No collection notice available for this credential type yet.',
    );
    expect(controller.missingCreateTypes, [
      'vehicle_registration',
      'first_aid',
    ]);
  });
}
