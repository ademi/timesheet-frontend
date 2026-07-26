import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/clients_controller.dart';
import '../controllers/public_client_invite_controller.dart';
import '../data/datasources/clients_remote_datasource.dart';
import '../data/repositories/clients_repository.dart';

class ClientsBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ClientsController>()) {
      Get.put(
        ClientsController(
          repository: Get.find<ClientsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }

  static void ensureShared() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(
        ApiClient(Get.find<TokenStorage>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ClientsRemoteDataSource>()) {
      Get.lazyPut<ClientsRemoteDataSource>(
        () => ClientsRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
          plainDio: Get.find<ApiClient>().plainDio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ClientsRepository>()) {
      Get.lazyPut<ClientsRepository>(
        () => ClientsRepository(remote: Get.find<ClientsRemoteDataSource>()),
        fenix: true,
      );
    }
  }
}

class PublicClientInviteBinding extends Bindings {
  @override
  void dependencies() {
    ClientsBinding.ensureShared();
    Get.lazyPut(
      () => PublicClientInviteController(
        repository: Get.find<ClientsRepository>(),
      ),
    );
  }
}
