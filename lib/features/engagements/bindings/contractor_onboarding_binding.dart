import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../credentials/bindings/credentials_binding.dart';
import '../../credentials/data/repositories/credentials_repository.dart';
import '../controllers/contractor_onboarding_controller.dart';
import '../data/repositories/engagements_repository.dart';
import 'engagements_binding.dart';

class ContractorOnboardingBinding extends Bindings {
  @override
  void dependencies() {
    EngagementsBinding.ensureShared();
    CredentialsBinding.ensureDependencies();
    if (!Get.isRegistered<SessionService>()) return;
    Get.put(
      ContractorOnboardingController(
        repository: Get.find<EngagementsRepository>(),
        credentialsRepository: Get.find<CredentialsRepository>(),
        session: Get.find<SessionService>(),
      ),
    );
  }
}
