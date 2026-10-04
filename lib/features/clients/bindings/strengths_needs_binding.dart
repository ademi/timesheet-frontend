import 'package:get/get.dart';

import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../core/getx/put_fresh.dart';
import '../../../core/services/session_service.dart';
import '../controllers/strengths_needs_controller.dart';
import '../data/repositories/clients_repository.dart';
import 'clients_binding.dart';

class StrengthsNeedsBinding extends Bindings {
  @override
  void dependencies() {
    ClientsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    final args = routeArguments();
    String? clientId = routeParam('clientId');
    String? assessmentId = routeParam('assessmentId');
    String? clientName;
    if (args is Map) {
      clientId ??= args['clientId']?.toString();
      assessmentId ??= args['assessmentId']?.toString();
      clientName = args['clientName']?.toString();
    }
    putFresh(
      () => StrengthsNeedsController(
        repository: Get.find<ClientsRepository>(),
        clientId: clientId,
        assessmentId: assessmentId,
        clientName: clientName,
      ),
    );
  }
}
