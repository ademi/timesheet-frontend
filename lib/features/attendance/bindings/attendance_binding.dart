import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/attendance_review_controller.dart';
import '../data/datasources/attendance_remote_datasource.dart';
import '../data/repositories/attendance_repository.dart';

class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
  }

  static void ensureShared() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<AttendanceRemoteDataSource>()) {
      Get.lazyPut<AttendanceRemoteDataSource>(
        () => AttendanceRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<AttendanceRepository>()) {
      Get.lazyPut<AttendanceRepository>(
        () => AttendanceRepository(
          remote: Get.find<AttendanceRemoteDataSource>(),
        ),
        fenix: true,
      );
    }
  }
}

class AttendanceReviewBinding extends Bindings {
  @override
  void dependencies() {
    AttendanceBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    final args = Get.arguments;
    String? visitId;
    if (args is Map && args['visitId'] != null) {
      visitId = args['visitId'].toString();
    }
    if (Get.isRegistered<AttendanceReviewController>()) {
      Get.delete<AttendanceReviewController>();
    }
    Get.put(
      AttendanceReviewController(
        repository: Get.find<AttendanceRepository>(),
        visitIdFilter: visitId,
      ),
    );
  }
}
