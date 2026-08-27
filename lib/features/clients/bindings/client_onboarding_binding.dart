import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../documents/data/document_pipeline.dart';
import '../controllers/client_onboarding_controller.dart';
import '../data/models/client_models.dart';
import '../data/repositories/clients_repository.dart';
import 'clients_binding.dart';

class ClientOnboardingBinding extends Bindings {
  @override
  void dependencies() {
    ClientsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ClientOnboardingController>()) {
      Get.put(
        ClientOnboardingController(
          repository: Get.find<ClientsRepository>(),
          session: Get.find<SessionService>(),
          documentPipeline: Get.isRegistered<DocumentPipeline>()
              ? Get.find<DocumentPipeline>()
              : null,
        ),
      );
    }
    final args = Get.arguments;
    if (args is ClientOut) {
      Get.find<ClientOnboardingController>().hydrateFromClient(args);
    }
  }
}
