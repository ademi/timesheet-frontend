import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../jobs/bindings/jobs_binding.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../controllers/contractor_visits_controller.dart';
import '../controllers/staff_visits_controller.dart';
import '../data/datasources/visits_remote_datasource.dart';
import '../data/repositories/visits_repository.dart';
import '../services/visit_location_service.dart';

class VisitsBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
  }

  static void ensureShared() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<VisitsRemoteDataSource>()) {
      Get.lazyPut<VisitsRemoteDataSource>(
        () =>
            VisitsRemoteDataSource(authenticatedDio: Get.find<ApiClient>().dio),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VisitsRepository>()) {
      Get.lazyPut<VisitsRepository>(
        () => VisitsRepository(remote: Get.find<VisitsRemoteDataSource>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VisitLocationService>()) {
      Get.put<VisitLocationService>(const VisitLocationService());
    }
  }
}

class StaffVisitsBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    JobsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<StaffVisitsController>()) {
      Get.put(
        StaffVisitsController(
          repository: Get.find<VisitsRepository>(),
          jobsRepository: Get.find<JobsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}

class ContractorVisitsBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ContractorVisitsController>()) {
      Get.put(
        ContractorVisitsController(
          repository: Get.find<VisitsRepository>(),
          session: Get.find<SessionService>(),
          location: Get.find<VisitLocationService>(),
        ),
      );
    }
  }
}
