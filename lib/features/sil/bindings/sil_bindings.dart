import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/sil_houses_controller.dart';
import '../data/datasources/sil_remote_datasource.dart';
import '../data/repositories/sil_repository.dart';

class SilHousesBinding extends Bindings {
  @override
  void dependencies() {
    _ensureShared();
    Get.lazyPut(
      () => SilHousesController(Get.find<SilRepository>()),
      fenix: true,
    );
  }

  static void _ensureShared() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<SilRemoteDataSource>()) {
      Get.lazyPut<SilRemoteDataSource>(
        () => SilRemoteDataSource(authenticatedDio: Get.find<ApiClient>().dio),
        fenix: true,
      );
    }
    if (!Get.isRegistered<SilRepository>()) {
      Get.lazyPut<SilRepository>(
        () => SilRepository(Get.find<SilRemoteDataSource>()),
        fenix: true,
      );
    }
  }
}

class SilHouseDetailBinding extends Bindings {
  @override
  void dependencies() {
    SilHousesBinding._ensureShared();
    final args = Get.arguments;
    final houseId =
        args is Map ? args['house_id']?.toString() : args?.toString();
    if (houseId == null || houseId.isEmpty) {
      throw StateError('sil house detail requires house_id');
    }
    Get.lazyPut(
      () => SilHouseDetailController(
        Get.find<SilRepository>(),
        houseId: houseId,
      ),
    );
  }
}
