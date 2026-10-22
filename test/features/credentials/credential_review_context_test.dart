import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/credentials/controllers/staff_credential_review_controller.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  test('CredentialReviewContextOut parses pack flags and points', () {
    final context = CredentialReviewContextOut.fromJson({
      'credentials': [
        {
          'id': 'c1',
          'contractor_id': 'ctr-1',
          'credential_type': 'passport_id',
          'status': 'active',
          'provenance_state': 'self_reported',
          'evidence_presence': 'present',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
          'id_points': 100,
        },
      ],
      'document_pack': 'support_worker_v1',
      'engagement_id': 'eng-1',
      'photo_id_points_total': 100,
      'onboarding_flags': {
        'wwcc_applicable': true,
        'qualifications_applicable': false,
      },
    });

    expect(context.documentPack, 'support_worker_v1');
    expect(context.photoIdPointsTotal, 100);
    expect(context.onboardingFlags['wwcc_applicable'], isTrue);
    expect(context.credentials, hasLength(1));
  });

  test('CredentialReviewContextOut parses sharing grant flags', () {
    final noGrant = CredentialReviewContextOut.fromJson({
      'credentials': [],
      'has_active_sharing_grant': false,
      'allow_source_evidence': null,
    });
    expect(noGrant.hasActiveSharingGrant, isFalse);
    expect(noGrant.allowSourceEvidence, isNull);
    expect(noGrant.credentials, isEmpty);

    final withGrant = CredentialReviewContextOut.fromJson({
      'credentials': [],
      'has_active_sharing_grant': true,
      'allow_source_evidence': false,
    });
    expect(withGrant.hasActiveSharingGrant, isTrue);
    expect(withGrant.allowSourceEvidence, isFalse);
  });

  test('load prefers review-context pack metadata', () async {
    Get.testMode = true;
    final credentials = _MockCredentialsRepository();
    final engagements = _MockEngagementsRepository();
    final pipeline = _MockDocumentPipeline();
    final session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => credentials.getReviewContext(
        'contractor-1',
        engagementId: 'engagement-1',
      ),
    ).thenAnswer(
      (_) async => CredentialReviewContextOut(
        credentials: [
          CredentialOut(
            id: 'c1',
            contractorId: 'contractor-1',
            credentialType: 'first_aid',
            status: 'active',
            provenanceState: 'self_reported',
            evidencePresence: 'present',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
        documentPack: 'support_worker_v1',
        engagementId: 'engagement-1',
        photoIdPointsTotal: 100,
        onboardingFlags: const {'wwcc_applicable': true},
      ),
    );
    when(
      () => pipeline.listEvidenceForContractor('contractor-1'),
    ).thenAnswer((_) async => const []);

    final controller = StaffCredentialReviewController(
      repository: credentials,
      engagementsRepository: engagements,
      session: session,
      documentPipeline: pipeline,
      contractorId: 'contractor-1',
      engagementId: 'engagement-1',
      showSnack: (_, __) {},
    );
    await controller.load();

    expect(controller.documentPack.value, 'support_worker_v1');
    expect(controller.photoIdPointsTotal.value, 100);
    expect(controller.onboardingFlags['wwcc_applicable'], isTrue);
    expect(controller.items, hasLength(1));
    verifyNever(
      () => credentials.listForTenantContractor(
        'contractor-1',
        engagementId: 'engagement-1',
      ),
    );
    Get.reset();
  });
}
