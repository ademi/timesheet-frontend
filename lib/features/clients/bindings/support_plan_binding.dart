import 'package:get/get.dart';

import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../core/getx/put_fresh.dart';
import '../../../core/services/session_service.dart';
import '../../documents/data/document_pipeline.dart';
import '../controllers/support_plan_controller.dart';
import '../data/repositories/clients_repository.dart';
import 'clients_binding.dart';

class SupportPlanBinding extends Bindings {
  @override
  void dependencies() {
    ClientsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;

    // GoRouter does not dispose GetX controllers on pop. Reusing the prior
    // instance left the previous client/plan stuck on support-plan re-enter.
    final args = routeArguments();
    String? clientId = routeParam('clientId');
    String? planId = routeParam('planId');
    String? clientName;
    String? ndisNumber;
    if (args is Map) {
      clientId ??= args['clientId']?.toString();
      planId ??= args['planId']?.toString();
      clientName = args['clientName']?.toString();
      ndisNumber = args['ndisNumber']?.toString();
    }
    putFresh(
      () => SupportPlanController(
        repository: Get.find<ClientsRepository>(),
        session: Get.find<SessionService>(),
        clientId: clientId,
        planId: planId,
        clientName: clientName,
        ndisNumber: ndisNumber,
        documentPipeline:
            Get.isRegistered<DocumentPipeline>()
                ? Get.find<DocumentPipeline>()
                : null,
      ),
    );
  }
}
