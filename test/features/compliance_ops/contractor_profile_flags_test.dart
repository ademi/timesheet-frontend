import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/compliance_ops/controllers/contractor_profile_controller.dart';
import 'package:rostiq/features/compliance_ops/data/repositories/compliance_ops_repository.dart';
import 'package:rostiq/features/contractor_me/data/models/contractor_me_models.dart';
import 'package:rostiq/features/contractor_me/data/repositories/contractor_me_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockComplianceOpsRepository extends Mock
    implements ComplianceOpsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockMeRepository extends Mock implements ContractorMeRepository {}

void main() {
  late _MockComplianceOpsRepository repository;
  late _MockSessionService session;
  late _MockMeRepository meRepository;
  late ContractorProfileController controller;

  setUp(() {
    Get.testMode = true;
    repository = _MockComplianceOpsRepository();
    session = _MockSessionService();
    meRepository = _MockMeRepository();

    when(() => session.hasPermission(any())).thenReturn(false);
    when(() => session.contractorId).thenReturn(RxnString('c1'));
    when(() => session.needsProfileCompletion).thenReturn(false.obs);
    when(() => repository.listNotificationEvents()).thenAnswer((_) async => []);
    when(() => repository.getContractorProfilePhoto()).thenAnswer(
      (_) async => const ProfilePhotoOut(hasPhoto: false),
    );
    when(() => meRepository.getMe()).thenAnswer(
      (_) async => ContractorMeOut(
        id: 'c1',
        userId: 'u1',
        fullName: 'Alex',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        profileOnboardingComplete: false,
      ),
    );

    controller = ContractorProfileController(
      repository: repository,
      session: session,
      meRepository: meRepository,
    );
  });

  tearDown(Get.reset);

  test('buildOnboardingFlagsPayload includes all four flags', () {
    controller.wwccApplicable.value = true;
    controller.qualificationsApplicable.value = false;
    controller.drivesParticipants.value = false;
    controller.usesOwnVehicle.value = null;

    expect(controller.buildOnboardingFlagsPayload(), {
      OnboardingFlagKeys.wwccApplicable: true,
      OnboardingFlagKeys.qualificationsApplicable: false,
      OnboardingFlagKeys.drivesParticipants: false,
      OnboardingFlagKeys.usesOwnVehicle: null,
    });
  });

  test('buildProfileSectionsTouchedPayload marks all three sections', () {
    expect(controller.buildProfileSectionsTouchedPayload(), {
      ProfileSectionKeys.screening: true,
      ProfileSectionKeys.qualifications: true,
      ProfileSectionKeys.checks: true,
    });
  });
}
