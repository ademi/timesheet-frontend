import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../../core/services/token_storage.dart';
import '../data/datasources/remote/attendance_remote_datasource.dart';
import '../data/repositories/attendance_repository.dart';

/// Ensures the attendance data layer (api client, datasource, repository) is
/// registered. Safe to call from any entry point that needs attendance data,
/// including admin-only screens reached without going through [HomeBinding].
abstract final class AttendanceModuleBinding {
  AttendanceModuleBinding._();

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

    if (!Get.isRegistered<AttendanceRemoteDataSource>()) {
      Get.put<AttendanceRemoteDataSource>(
        AttendanceRemoteDataSource(
          dio: Get.find<AttendanceApiClient>().dio,
        ),
        permanent: true,
      );
    }

    if (!Get.isRegistered<AttendanceRepository>()) {
      Get.put<AttendanceRepository>(
        AttendanceRepository(
          remote: Get.find<AttendanceRemoteDataSource>(),
          tokenStorage: Get.find<TokenStorage>(),
        ),
        permanent: true,
      );
    }
  }
}
