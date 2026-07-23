import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../../core/services/token_storage.dart';
import '../data/datasources/remote/form_remote_datasource.dart';
import '../data/repositories/form_repository.dart';

abstract final class FormModuleBinding {
  FormModuleBinding._();

  static void ensureDependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
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
    if (!Get.isRegistered<FormRemoteDataSource>()) {
      Get.put<FormRemoteDataSource>(
        FormRemoteDataSource(dio: Get.find<AttendanceApiClient>().dio),
        permanent: true,
      );
    }
    if (!Get.isRegistered<FormRepository>()) {
      Get.put<FormRepository>(
        FormRepository(
          remote: Get.find<FormRemoteDataSource>(),
          tokenStorage: Get.find<TokenStorage>(),
        ),
        permanent: true,
      );
    }
  }
}
