import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../../core/services/token_storage.dart';
import '../data/datasources/remote/payment_batch_remote_datasource.dart';
import '../data/repositories/payment_batch_repository.dart';

abstract final class PaymentBatchModuleBinding {
  PaymentBatchModuleBinding._();

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
    if (!Get.isRegistered<PaymentBatchRemoteDataSource>()) {
      Get.put<PaymentBatchRemoteDataSource>(
        PaymentBatchRemoteDataSource(dio: Get.find<AttendanceApiClient>().dio),
        permanent: true,
      );
    }
    if (!Get.isRegistered<PaymentBatchRepository>()) {
      Get.put<PaymentBatchRepository>(
        PaymentBatchRepository(
          remote: Get.find<PaymentBatchRemoteDataSource>(),
          tokenStorage: Get.find<TokenStorage>(),
        ),
        permanent: true,
      );
    }
  }
}
