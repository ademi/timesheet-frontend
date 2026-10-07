import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../../app/routes/middlewares/auth_route_utils.dart';
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

    // Do not putFresh on every enter: step changes call AppNavigator.replace
    // and re-run this binding. Wipe only when targeting a different client, or
    // when the route was left (see [release] / go_router onExit).
    final incomingId = _incomingClientId();
    if (Get.isRegistered<ClientOnboardingController>()) {
      final existingId =
          Get.find<ClientOnboardingController>().client.value?.id;
      if (incomingId != null &&
          existingId != null &&
          incomingId != existingId) {
        Get.delete<ClientOnboardingController>(force: true);
      }
    }

    if (!Get.isRegistered<ClientOnboardingController>()) {
      Get.put(
        ClientOnboardingController(
          repository: Get.find<ClientsRepository>(),
          session: Get.find<SessionService>(),
          documentPipeline:
              Get.isRegistered<DocumentPipeline>()
                  ? Get.find<DocumentPipeline>()
                  : null,
        ),
      );
    }
    // Defer hydrate: ensureHydratedFromRoute → syncOnboardingRoute may
    // AppNavigator.replace, which must not run inside GoRouter's builder.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<ClientOnboardingController>()) return;
      // ignore: discarded_futures
      Get.find<ClientOnboardingController>().ensureHydratedFromRoute();
    });
  }

  /// Drop controller when leaving the onboarding route (GoRouter onExit).
  static void release() {
    if (Get.isRegistered<ClientOnboardingController>()) {
      Get.delete<ClientOnboardingController>(force: true);
    }
  }

  static String? _incomingClientId() {
    final fromRoute = routeParam('id');
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final args = routeArguments();
    if (args is ClientOut) return args.id;
    if (args is Map) {
      final id = args['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }
}
