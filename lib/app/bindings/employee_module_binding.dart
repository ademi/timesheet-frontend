import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../data/datasources/remote/employee_remote_datasource.dart';
import '../data/repositories/employee_repository.dart';

abstract final class EmployeeModuleBinding {
  EmployeeModuleBinding._();

  static void ensureDependencies() {
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(GetStorage()), permanent: true);
    }

    if (!Get.isRegistered<AttendanceApiClient>()) {
      Get.put<AttendanceApiClient>(
        AttendanceApiClient(GetStorage(), Get.find<ApiClient>().plainDio),
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
        EmployeeRepository(remote: Get.find<EmployeeRemoteDataSource>()),
        permanent: true,
      );
    }
  }
}
