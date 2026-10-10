import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/credentials/controllers/credentials_controller.dart';
import 'package:rostiq/features/credentials/controllers/staff_credential_review_controller.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

CredentialOut _credential({
  required String id,
  String status = 'active',
  String provenance = 'contractor_asserted',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return CredentialOut(
    id: id,
    contractorId: 'contractor-1',
    credentialType: 'vehicle_registration',
    status: status,
    provenanceState: provenance,
    evidencePresence: 'present',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
    clearCredentialCategoryLabelCache();
  });

  tearDown(Get.reset);

  test('requiresNewReviewCycle is true after admin acceptance', () {
    final repository = _MockCredentialsRepository();
    final pipeline = _MockDocumentPipeline();
    final compliance = _MockComplianceRepository();
    final session = _MockSessionService();

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

    final controller = CredentialsController(
      repository: repository,
      documentPipeline: pipeline,
      complianceRepository: compliance,
      session: session,
    );

    expect(
      controller.requiresNewReviewCycle(
        _credential(id: '1', provenance: 'reviewer_sighted'),
      ),
      isTrue,
    );
    expect(
      controller.requiresNewReviewCycle(
        _credential(id: '2', status: 'accepted'),
      ),
      isTrue,
    );
    expect(
      controller.requiresNewReviewCycle(
        _credential(id: '3', provenance: 'contractor_asserted'),
      ),
      isFalse,
    );
  });

  test(
    'staff load hides superseded and keeps awaiting resubmit reviewable',
    () async {
      final credentials = _MockCredentialsRepository();
      final engagements = _MockEngagementsRepository();
      final pipeline = _MockDocumentPipeline();
      final session = _MockSessionService();
      when(() => session.hasPermission(any())).thenReturn(true);

      when(
        () => credentials.listForTenantContractor(
          'contractor-1',
          engagementId: 'engagement-1',
        ),
      ).thenAnswer(
        (_) async => [
          _credential(id: 'old', status: 'superseded'),
          _credential(
            id: 'new',
            status: 'accepted',
            provenance: 'contractor_asserted',
          ),
        ],
      );
      when(
        () => pipeline.listEvidenceForContractor('contractor-1'),
      ).thenAnswer((_) async => []);

      final review = StaffCredentialReviewController(
        repository: credentials,
        engagementsRepository: engagements,
        session: session,
        documentPipeline: pipeline,
        contractorId: 'contractor-1',
        engagementId: 'engagement-1',
        showSnack: (_, __) {},
      );
      review.reviewDecisionsByCredentialId['new'] = 'accepted';

      await review.load();

      expect(review.items.map((c) => c.id), ['new']);
      expect(review.reviewDecisionFor('new'), isNull);
      expect(review.reviewActionsFor('new').acceptEnabled, isTrue);
      expect(review.reviewActionsFor('new').rejectEnabled, isTrue);
    },
  );
}
