import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/services/token_storage.dart';
import '../controllers/branch_gateway_controller.dart';
import '../data/datasources/remote/branch_remote_datasource.dart';
import '../data/repositories/branch_repository.dart';

class BranchGatewayBinding extends Bindings {
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

    if (!Get.isRegistered<BranchRemoteDataSource>()) {
      Get.put<BranchRemoteDataSource>(
        BranchRemoteDataSource(dio: Get.find<ApiClient>().dio),
        permanent: true,
      );
    }

    if (!Get.isRegistered<BranchRepository>()) {
      Get.put<BranchRepository>(
        BranchRepository(remote: Get.find<BranchRemoteDataSource>()),
        permanent: true,
      );
    }

    Get.lazyPut<BranchGatewayController>(
      () => BranchGatewayController(
        branchRepository: Get.find<BranchRepository>(),
        tokenStorage: Get.find<TokenStorage>(),
      ),
    );
  }
}
