import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/contractor_schedule_controller.dart';
import '../data/datasources/contractor_schedule_remote_datasource.dart';
import '../data/repositories/contractor_schedule_repository.dart';

class ContractorScheduleBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(
        ApiClient(Get.find<TokenStorage>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ContractorScheduleRemoteDataSource>()) {
      Get.lazyPut<ContractorScheduleRemoteDataSource>(
        () => ContractorScheduleRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ContractorScheduleRepository>()) {
      Get.lazyPut<ContractorScheduleRepository>(
        () => ContractorScheduleRepository(
          remote: Get.find<ContractorScheduleRemoteDataSource>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ContractorScheduleController>()) {
      Get.put(
        ContractorScheduleController(
          repository: Get.find<ContractorScheduleRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}
