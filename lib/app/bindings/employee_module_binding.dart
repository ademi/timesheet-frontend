import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../../core/services/token_storage.dart';
import '../data/datasources/remote/employee_remote_datasource.dart';
import '../data/repositories/employee_repository.dart';

abstract final class EmployeeModuleBinding {
  EmployeeModuleBinding._();

  static void ensureDependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }

    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(
        ApiClient(Get.find<TokenStorage>()),
        permanent: true,
      );
    }

    if (!Get.isRegistered<AttendanceApiClient>()) {
      Get.put<AttendanceApiClient>(
        AttendanceApiClient(
          Get.find<TokenStorage>(),
          Get.find<ApiClient>().plainDio,
        ),
        permanent: true,
      );
    }

    if (!Get.isRegistered<EmployeeRemoteDataSource>()) {
      Get.put<EmployeeRemoteDataSource>(
        EmployeeRemoteDataSource(dio: Get.find<AttendanceApiClient>().dio),
        permanent: true,
      );
    }

    if (!Get.isRegistered<EmployeeRepository>()) {
      Get.put<EmployeeRepository>(
        EmployeeRepository(
          remote: Get.find<EmployeeRemoteDataSource>(),
          tokenStorage: Get.find<TokenStorage>(),
        ),
        permanent: true,
      );
    }
  }
}
