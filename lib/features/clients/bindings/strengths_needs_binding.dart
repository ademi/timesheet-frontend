import 'package:get/get.dart';

import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../core/services/session_service.dart';
import '../controllers/strengths_needs_controller.dart';
import '../data/repositories/clients_repository.dart';
import 'clients_binding.dart';

class StrengthsNeedsBinding extends Bindings {
  @override
  void dependencies() {
    ClientsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (Get.isRegistered<StrengthsNeedsController>()) {
      Get.delete<StrengthsNeedsController>(force: true);
    }
    final args = routeArguments();
    String? clientId = routeParam('clientId');
    String? assessmentId = routeParam('assessmentId');
    String? clientName;
    if (args is Map) {
      clientId ??= args['clientId']?.toString();
      assessmentId ??= args['assessmentId']?.toString();
      clientName = args['clientName']?.toString();
    }
    Get.put(
      StrengthsNeedsController(
        repository: Get.find<ClientsRepository>(),
        clientId: clientId,
        assessmentId: assessmentId,
        clientName: clientName,
      ),
    );
  }
}
