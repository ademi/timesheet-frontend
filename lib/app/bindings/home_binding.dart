import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../controllers/attendance_controller.dart';
import '../data/datasources/remote/attendance_remote_datasource.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    final storage = GetStorage();

    if (!Get.isRegistered<AttendanceApiClient>()) {
      Get.put<AttendanceApiClient>(
        AttendanceApiClient(storage, Get.find<ApiClient>().plainDio),
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
        ),
        permanent: true,
      );
    }
    Get.lazyPut<AttendanceController>(
      () => AttendanceController(
        repository: Get.find<AttendanceRepository>(),
        authRepository: Get.find<AuthRepository>(),
      ),
    );
  }
}
