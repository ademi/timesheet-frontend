import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/engagements/controllers/workforce_controller.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late WorkforceController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    final session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    controller = WorkforceController(
      repository: _MockEngagementsRepository(),
      credentialsRepository: _MockCredentialsRepository(),
      session: session,
    );
  });

  tearDown(Get.reset);

  test('openCredentialReview is blocked when engagement is ended', () {
    final now = DateTime.utc(2026, 1, 1);
    controller.openCredentialReview(
      EngagementOut(
        id: 'e1',
        tenantId: 't1',
        contractorId: 'c1',
        status: 'ended',
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(
      controller.errorMessage.value,
      'This worker is no longer in your workforce.',
    );
  });
}
