import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/complete_account_controller.dart';
import '../data/datasources/contractor_me_remote_datasource.dart';
import '../data/repositories/contractor_me_repository.dart';

class CompleteAccountBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<ContractorMeRemoteDataSource>()) {
      Get.lazyPut<ContractorMeRemoteDataSource>(
        () => ContractorMeRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
      );
    }
    if (!Get.isRegistered<ContractorMeRepository>()) {
      Get.lazyPut<ContractorMeRepository>(
        () => ContractorMeRepository(
          remote: Get.find<ContractorMeRemoteDataSource>(),
        ),
      );
    }
    Get.lazyPut(
      () => CompleteAccountController(
        repository: Get.find<ContractorMeRepository>(),
        session: Get.isRegistered<SessionService>()
            ? Get.find<SessionService>()
            : null,
      ),
    );
  }
}
