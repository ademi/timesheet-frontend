import 'package:get/get.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/token_storage.dart';
import '../controllers/contractor_register_controller.dart';
import '../data/datasources/contractor_register_remote_datasource.dart';
import '../data/repositories/contractor_register_repository.dart';

class ContractorRegisterBinding extends Bindings {
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
    if (!Get.isRegistered<ContractorRegisterRemoteDataSource>()) {
      Get.lazyPut<ContractorRegisterRemoteDataSource>(
        () => ContractorRegisterRemoteDataSource(
          plainDio: Get.find<ApiClient>().plainDio,
        ),
      );
    }
    if (!Get.isRegistered<ContractorRegisterRepository>()) {
      Get.lazyPut<ContractorRegisterRepository>(
        () => ContractorRegisterRepository(
          remote: Get.find<ContractorRegisterRemoteDataSource>(),
        ),
      );
    }
    if (!Get.isRegistered<ContractorRegisterController>()) {
      Get.lazyPut<ContractorRegisterController>(
        () => ContractorRegisterController(
          repository: Get.find<ContractorRegisterRepository>(),
        ),
      );
    }
  }
}
