import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/contractor_onboarding/data/models/compliance_models.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/engagements/controllers/contractor_engagements_controller.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeLegalEventCreate extends Fake implements LegalEventCreate {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeLegalEventCreate());
  });

  tearDown(Get.reset);

  test(
    'shows sharing authorisation retry guidance when accept legal event is unavailable',
    () async {
      final compliance = _MockComplianceRepository();
      final controller = ContractorEngagementsController(
        repository: _MockEngagementsRepository(),
        complianceRepository: compliance,
        session: _MockSessionService(),
      );
      controller.beginAccept(
        EngagementOut(
          id: 'engagement-1',
          tenantId: 'tenant-1',
          contractorId: 'contractor-1',
          status: 'invited',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      controller.understoodWithdrawEffects.value = true;
      when(
        () => compliance.createLegalEvent(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const AppFailure(
          code: 'legal_document_unavailable',
          message: 'This legal document is not available yet.',
          presentation: AppFailurePresentation.toast,
        ),
      );

      final accepted = await controller.confirmAccept();

      expect(accepted, isFalse);
      expect(
        controller.errorMessage.value,
        'Could not record sharing authorisation. Try again or contact support.',
      );
    },
  );
}
