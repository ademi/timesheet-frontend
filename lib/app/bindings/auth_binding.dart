import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/services/token_storage.dart';
import '../controllers/auth_controller.dart';
import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/repositories/auth_repository.dart';
import '../services/push_notification_service.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }

    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(
        ApiClient(Get.find<TokenStorage>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<AuthRemoteDataSource>()) {
      final client = Get.find<ApiClient>();
      Get.put<AuthRemoteDataSource>(
        AuthRemoteDataSource(
          plainDio: client.plainDio,
          authenticatedDio: client.dio,
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<AuthRepository>()) {
      Get.put<AuthRepository>(
        AuthRepository(
          remote: Get.find<AuthRemoteDataSource>(),
          storage: Get.find<TokenStorage>(),
        ),
        permanent: true,
      );
    }
    if (!Get.isRegistered<PushNotificationService>()) {
      Get.put<PushNotificationService>(
        PushNotificationService(authenticatedDio: Get.find<ApiClient>().dio),
        permanent: true,
      );
    }
    if (!Get.isRegistered<AuthController>()) {
      Get.put<AuthController>(
        AuthController(authRepository: Get.find<AuthRepository>()),
        permanent: true,
      );
    }
  }
}
