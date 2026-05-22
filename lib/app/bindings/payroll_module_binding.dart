import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../data/datasources/remote/payroll_remote_datasource.dart';
import '../data/repositories/payroll_repository.dart';

abstract final class PayrollModuleBinding {
  PayrollModuleBinding._();

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

    if (!Get.isRegistered<PayrollRemoteDataSource>()) {
      Get.put<PayrollRemoteDataSource>(
        PayrollRemoteDataSource(dio: Get.find<AttendanceApiClient>().dio),
        permanent: true,
      );
    }

    if (!Get.isRegistered<PayrollRepository>()) {
      Get.put<PayrollRepository>(
        PayrollRepository(remote: Get.find<PayrollRemoteDataSource>()),
        permanent: true,
      );
    }
  }
}
