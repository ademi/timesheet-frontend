import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../clients/bindings/clients_binding.dart';
import '../../engagements/bindings/engagements_binding.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../controllers/jobs_controller.dart';
import '../controllers/ongoing_support_controller.dart';
import '../data/datasources/jobs_remote_datasource.dart';
import '../data/repositories/jobs_repository.dart';

class JobsBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<JobsController>()) {
      Get.put(
        JobsController(
          repository: Get.find<JobsRepository>(),
          clientsRepository: Get.find<ClientsRepository>(),
          engagementsRepository: Get.find<EngagementsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }

  static void ensureShared() {
    ClientsBinding.ensureShared();
    EngagementsBinding.ensureShared();
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<JobsRemoteDataSource>()) {
      Get.lazyPut<JobsRemoteDataSource>(
        () => JobsRemoteDataSource(authenticatedDio: Get.find<ApiClient>().dio),
        fenix: true,
      );
    }
    if (!Get.isRegistered<JobsRepository>()) {
      Get.lazyPut<JobsRepository>(
        () => JobsRepository(remote: Get.find<JobsRemoteDataSource>()),
        fenix: true,
      );
    }
  }
}

class OngoingSupportBinding extends Bindings {
  @override
  void dependencies() {
    JobsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    Get.put(
      OngoingSupportController(
        jobsRepository: Get.find<JobsRepository>(),
        clientsRepository: Get.find<ClientsRepository>(),
        engagementsRepository: Get.find<EngagementsRepository>(),
        session: Get.find<SessionService>(),
      ),
    );
  }
}
