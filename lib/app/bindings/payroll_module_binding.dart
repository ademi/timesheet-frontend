import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../../core/services/token_storage.dart';
import '../data/datasources/remote/payroll_remote_datasource.dart';
import '../data/repositories/payroll_repository.dart';

abstract final class PayrollModuleBinding {
  PayrollModuleBinding._();

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

    if (!Get.isRegistered<PayrollRemoteDataSource>()) {
      Get.put<PayrollRemoteDataSource>(
        PayrollRemoteDataSource(dio: Get.find<AttendanceApiClient>().dio),
        permanent: true,
      );
    }

    if (!Get.isRegistered<PayrollRepository>()) {
      Get.put<PayrollRepository>(
        PayrollRepository(
          remote: Get.find<PayrollRemoteDataSource>(),
          tokenStorage: Get.find<TokenStorage>(),
        ),
        permanent: true,
      );
    }
  }
}
