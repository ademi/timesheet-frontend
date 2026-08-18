import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/credentials/controllers/staff_credential_review_controller.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeCredentialReviewCreateRequest extends Fake
    implements CredentialReviewCreateRequest {}

void main() {
  late _MockCredentialsRepository credentials;
  late _MockEngagementsRepository engagements;
  late _MockDocumentPipeline pipeline;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    registerFallbackValue(_FakeCredentialReviewCreateRequest());
    credentials = _MockCredentialsRepository();
    engagements = _MockEngagementsRepository();
    pipeline = _MockDocumentPipeline();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
  });

  tearDown(Get.reset);

  CredentialOut sampleCredential() => CredentialOut(
    id: 'credential-1',
    contractorId: 'contractor-1',
    credentialType: 'first_aid',
    status: 'active',
    provenanceState: 'contractor_asserted',
    evidencePresence: 'present',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  StaffCredentialReviewController buildController({
    String? engagementId = 'engagement-1',
  }) {
    return StaffCredentialReviewController(
      repository: credentials,
      engagementsRepository: engagements,
      session: session,
      documentPipeline: pipeline,
      contractorId: 'contractor-1',
      engagementId: engagementId,
      showSnack: (_, __) {},
    );
  }

  test(
    'load sets needsShareRequest when credentials require a sharing grant',
    () async {
      when(
        () => credentials.listForTenantContractor(
          'contractor-1',
          engagementId: 'engagement-1',
        ),
      ).thenThrow(
        const AppFailure(
          code: 'sharing_grant_required',
          message: 'sharing_grant_required',
          presentation: AppFailurePresentation.inline,
          statusCode: 403,
        ),
      );

      final controller = buildController();
      await controller.load();

      expect(controller.needsShareRequest.value, isTrue);
      expect(controller.errorMessage.value, isNull);
      expect(controller.items, isEmpty);
    },
  );

  test('requestAccess posts sharing-access-request for engagement', () async {
    when(
      () => engagements.createSharingAccessRequest(
        engagementId: 'engagement-1',
      ),
    ).thenAnswer((_) async {});
    when(
      () => credentials.listForTenantContractor(
        'contractor-1',
        engagementId: 'engagement-1',
      ),
    ).thenThrow(
      const AppFailure(
        code: 'sharing_grant_required',
        message: 'sharing_grant_required',
        presentation: AppFailurePresentation.inline,
        statusCode: 403,
      ),
    );
    final snacks = <String>[];
    final controller = StaffCredentialReviewController(
      repository: credentials,
      engagementsRepository: engagements,
      session: session,
      documentPipeline: pipeline,
      contractorId: 'contractor-1',
      engagementId: 'engagement-1',
      showSnack: (title, message) => snacks.add('$title|$message'),
    );
    await controller.load();
    final ok = await controller.requestAccess();

    expect(ok, isTrue);
    verify(
      () => engagements.createSharingAccessRequest(
        engagementId: 'engagement-1',
      ),
    ).called(1);
    expect(
      snacks.single,
      'Request sent|Request sent. Waiting for contractor approval.',
    );
    // Keep empty-state visible until contractor approves.
    expect(controller.needsShareRequest.value, isTrue);
  });

  test('requestAccess fails when engagement context missing', () async {
    when(
      () => session.hasPermission(AppPermissions.credentialsRead),
    ).thenReturn(true);
    final controller = StaffCredentialReviewController(
      repository: credentials,
      engagementsRepository: engagements,
      session: session,
      documentPipeline: pipeline,
      contractorId: 'contractor-1',
      showSnack: (_, __) {},
    );

    final ok = await controller.requestAccess();

    expect(ok, isFalse);
    expect(
      controller.errorMessage.value,
      'Open credential review from Workforce.',
    );
    verifyNever(
      () => engagements.createSharingAccessRequest(
        engagementId: any(named: 'engagementId'),
      ),
    );
  });

  test('load seeds reviewDecisionsByCredentialId from credential status', () async {
    final accepted = CredentialOut(
      id: 'cred-accepted',
      contractorId: 'contractor-1',
      credentialType: 'first_aid',
      status: 'accepted',
      provenanceState: 'reviewer_sighted',
      evidencePresence: 'present',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final pending = CredentialOut(
      id: 'cred-pending',
      contractorId: 'contractor-1',
      credentialType: 'insurance',
      status: 'pending',
      provenanceState: 'contractor_asserted',
      evidencePresence: 'present',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    when(
      () => credentials.listForTenantContractor(
        'contractor-1',
        engagementId: 'engagement-1',
      ),
    ).thenAnswer((_) async => [accepted, pending]);
    when(
      () => pipeline.listEvidenceForContractor('contractor-1'),
    ).thenAnswer((_) async => const []);

    final controller = buildController();
    await controller.load();

    expect(
      controller.reviewDecisionsByCredentialId['cred-accepted'],
      'accepted',
    );
    expect(
      controller.reviewDecisionsByCredentialId['cred-pending'],
      'pending',
    );
  });

  test('prepareReview opens reason picker for reject decisions', () async {
    final controller = buildController();

    controller.prepareReview(
      credential: sampleCredential(),
      decision: 'rejected',
    );

    expect(
      controller.isReasonPickerOpenFor(sampleCredential().id, 'rejected'),
      isTrue,
    );
    expect(controller.selectedReasonCode.value, isNull);
  });

  test('prepareReview submits accept immediately without reason picker', () async {
    when(
      () => credentials.createReview(
        engagementId: 'engagement-1',
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => CredentialReviewOut(
        id: 'review-1',
        tenantId: 'tenant-1',
        engagementId: 'engagement-1',
        credentialId: sampleCredential().id,
        requirementCategory: sampleCredential().credentialType,
        decision: 'accepted',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    when(
      () => credentials.listForTenantContractor(
        'contractor-1',
        engagementId: 'engagement-1',
      ),
    ).thenAnswer((_) async => [sampleCredential()]);
    when(
      () => pipeline.listEvidenceForContractor('contractor-1'),
    ).thenAnswer((_) async => const []);

    final controller = buildController();
    controller.prepareReview(
      credential: sampleCredential(),
      decision: 'accepted',
    );
    await Future<void>.delayed(Duration.zero);

    verify(
      () => credentials.createReview(
        engagementId: 'engagement-1',
        body: any(named: 'body'),
      ),
    ).called(1);
    expect(controller.reasonCredentialId.value, isNull);
    expect(controller.pendingReasonDecision.value, isNull);
  });
}
