import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/engagements/controllers/workforce_controller.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';

class _MockEngagementsRepository extends Mock implements EngagementsRepository {}

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeEngagementInvitePreviewRequest extends Fake
    implements EngagementInvitePreviewRequest {}

class _FakeEngagementInviteRequest extends Fake
    implements EngagementInviteRequest {}

void main() {
  late _MockEngagementsRepository repository;
  late _MockCredentialsRepository credentials;
  late _MockSessionService session;
  late WorkforceController controller;

  setUpAll(() {
    registerFallbackValue(_FakeEngagementInvitePreviewRequest());
    registerFallbackValue(_FakeEngagementInviteRequest());
  });

  setUp(() {
    Get.testMode = true;
    repository = _MockEngagementsRepository();
    credentials = _MockCredentialsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(false);
    when(() => session.hasPermission(AppPermissions.contractorsInvite))
        .thenReturn(true);
    controller = WorkforceController(
      repository: repository,
      credentialsRepository: credentials,
      session: session,
    );
  });

  tearDown(Get.reset);

  test('submitInvite normalizes email to lowercase', () async {
    controller.emailCtrl.text = 'Sam.Example@Provider.COM';
    controller.selectedCategories.add('ndis_worker_screening');

    when(
      () => repository.previewInvite(any()),
    ).thenAnswer(
      (_) async => const EngagementInvitePreviewOut(
        outcome: 'existing_contractor',
        message: 'ok',
      ),
    );
    when(() => repository.invite(any())).thenAnswer(
      (_) async => EngagementInviteResponse(
        kind: 'engagement',
        engagement: EngagementOut(
          id: 'eng-1',
          tenantId: 'tenant-1',
          contractorId: 'ctr-1',
          status: 'invited',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ),
    );

    await controller.submitInvite();

    final preview =
        verify(() => repository.previewInvite(captureAny())).captured.single
            as EngagementInvitePreviewRequest;
    expect(preview.email, 'sam.example@provider.com');

    final invite =
        verify(() => repository.invite(captureAny())).captured.single
            as EngagementInviteRequest;
    expect(invite.email, 'sam.example@provider.com');
  });
}
