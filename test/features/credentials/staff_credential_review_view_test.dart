import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/credentials/controllers/staff_credential_review_controller.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/credentials/views/staff_credential_review_view.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

class _MockSessionService extends Mock implements SessionService {}

CredentialOut _sampleCredential() => CredentialOut(
  id: 'credential-1',
  contractorId: 'contractor-1',
  credentialType: 'first_aid',
  status: 'active',
  provenanceState: 'contractor_asserted',
  evidencePresence: 'present',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late _MockCredentialsRepository credentials;
  late _MockEngagementsRepository engagements;
  late _MockDocumentPipeline pipeline;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    credentials = _MockCredentialsRepository();
    engagements = _MockEngagementsRepository();
    pipeline = _MockDocumentPipeline();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
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
  });

  tearDown(Get.reset);

  testWidgets(
    'shows share-request empty state instead of raw 403 detail',
    (tester) async {
      final controller = StaffCredentialReviewController(
        repository: credentials,
        engagementsRepository: engagements,
        session: session,
        documentPipeline: pipeline,
        contractorId: 'contractor-1',
        engagementId: 'engagement-1',
      );
      Get.put(controller);
      await controller.load();

      await tester.pumpWidget(
        const GetMaterialApp(home: StaffCredentialReviewView()),
      );
      await tester.pump();

      expect(
        find.text(
          'This contractor has not shared credentials with your organisation yet.',
        ),
        findsOneWidget,
      );
      expect(find.text('Request access'), findsOneWidget);
      expect(find.text('sharing_grant_required'), findsNothing);
      expect(find.textContaining('403'), findsNothing);
    },
  );

  testWidgets(
    'shows reason picker only after reject is tapped',
    (tester) async {
      when(
        () => credentials.listForTenantContractor(
          'contractor-1',
          engagementId: 'engagement-1',
        ),
      ).thenAnswer((_) async => [_sampleCredential()]);
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
      );
      Get.put(controller);
      await controller.load();

      await tester.pumpWidget(
        const GetMaterialApp(home: StaffCredentialReviewView()),
      );
      await tester.pump();

      expect(find.text('Reason code'), findsNothing);

      await tester.tap(find.text('Reject'));
      await tester.pump();

      expect(find.text('Why are you rejecting this credential?'), findsOneWidget);
      expect(find.text('Reason code'), findsOneWidget);
      expect(find.text('Confirm reject'), findsOneWidget);
    },
  );

  testWidgets(
    'reject without submitted certificate shows error',
    (tester) async {
      when(
        () => credentials.listForTenantContractor(
          'contractor-1',
          engagementId: 'engagement-1',
        ),
      ).thenAnswer(
        (_) async => [
          CredentialOut(
            id: 'credential-1',
            contractorId: 'contractor-1',
            credentialType: 'first_aid',
            status: 'active',
            provenanceState: 'contractor_asserted',
            evidencePresence: 'none',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
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
      );
      Get.put(controller);
      await controller.load();

      await tester.pumpWidget(
        const GetMaterialApp(home: StaffCredentialReviewView()),
      );
      await tester.pump();

      await tester.tap(find.text('Reject'));
      await tester.pump();

      expect(
        find.text('No certificate has been submitted to reject.'),
        findsOneWidget,
      );
      expect(find.text('Why are you rejecting this credential?'), findsNothing);
    },
  );
}
