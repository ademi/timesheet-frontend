import 'package:get/get.dart';

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
    if (!Get.isRegistered<SupportPlanController>()) {
      final args = Get.arguments;
      String? clientId;
      String? planId;
      String? clientName;
      String? ndisNumber;
      if (args is Map) {
        clientId = args['clientId']?.toString();
        planId = args['planId']?.toString();
        clientName = args['clientName']?.toString();
        ndisNumber = args['ndisNumber']?.toString();
      }
      Get.put(
        SupportPlanController(
          repository: Get.find<ClientsRepository>(),
          clientId: clientId,
          planId: planId,
          clientName: clientName,
          ndisNumber: ndisNumber,
          documentPipeline: Get.isRegistered<DocumentPipeline>()
              ? Get.find<DocumentPipeline>()
              : null,
        ),
      );
    }
  }
}
