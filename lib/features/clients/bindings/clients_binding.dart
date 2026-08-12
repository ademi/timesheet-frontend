import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../documents/data/datasources/documents_remote_datasource.dart';
import '../../documents/data/document_pipeline.dart';
import '../../visits/bindings/visits_binding.dart';
import '../../visits/data/repositories/visits_repository.dart';
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
          documentPipeline: Get.find<DocumentPipeline>(),
          visitsRepository: Get.find<VisitsRepository>(),
        ),
      );
    }
  }

  static void ensureShared() {
    VisitsBinding.ensureShared();
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
    if (!Get.isRegistered<DocumentsRemoteDataSource>()) {
      Get.lazyPut<DocumentsRemoteDataSource>(
        () => DocumentsRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
          plainDio: Get.find<ApiClient>().plainDio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<DocumentPipeline>()) {
      Get.lazyPut<DocumentPipeline>(
        () => DocumentPipeline(remote: Get.find<DocumentsRemoteDataSource>()),
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
