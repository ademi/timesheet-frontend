import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/services/token_storage.dart';
import '../controllers/shift_schedule_controller.dart';
import '../data/datasources/remote/branch_remote_datasource.dart';
import '../data/repositories/branch_repository.dart';
import '../data/repositories/scheduling_repository.dart';
import 'scheduling_module_binding.dart';

class ShiftScheduleBinding extends Bindings {
  @override
  void dependencies() {
    SchedulingModuleBinding.ensureDependencies();

    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
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

    Get.lazyPut<ShiftScheduleController>(
      () => ShiftScheduleController(
        schedulingRepository: Get.find<SchedulingRepository>(),
        branchRepository: Get.find<BranchRepository>(),
        tokenStorage: Get.find<TokenStorage>(),
      ),
    );
  }
}
