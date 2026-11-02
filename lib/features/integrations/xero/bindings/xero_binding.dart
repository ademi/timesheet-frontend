import 'package:get/get.dart';

import '../../../../core/getx/put_fresh.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/token_storage.dart';
import '../../../engagements/bindings/engagements_binding.dart';
import '../../../engagements/data/repositories/engagements_repository.dart';
import '../controllers/xero_settings_controller.dart';
import '../data/datasources/xero_remote_datasource.dart';
import '../data/repositories/xero_repository.dart';

class XeroBinding extends Bindings {
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
    if (!Get.isRegistered<XeroRemoteDataSource>()) {
      Get.lazyPut<XeroRemoteDataSource>(
        () => XeroRemoteDataSource(authenticatedDio: Get.find<ApiClient>().dio),
        fenix: true,
      );
    }
    if (!Get.isRegistered<XeroRepository>()) {
      Get.lazyPut<XeroRepository>(
        () => XeroRepository(remote: Get.find<XeroRemoteDataSource>()),
        fenix: true,
      );
    }
  }
}

class XeroSettingsBinding extends Bindings {
  @override
  void dependencies() {
    XeroBinding.ensureShared();
    EngagementsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    putOrReenter(
      () => XeroSettingsController(
        xero: Get.find<XeroRepository>(),
        session: Get.find<SessionService>(),
        engagements: Get.find<EngagementsRepository>(),
      ),
      onReenter: (c) => c.onScreenReenter(),
    );
  }
}
