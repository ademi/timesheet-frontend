import 'package:get/get.dart';

import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../core/getx/put_fresh.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/sil_houses_controller.dart';
import '../data/datasources/sil_remote_datasource.dart';
import '../data/repositories/sil_repository.dart';

class SilHousesBinding extends Bindings {
  @override
  void dependencies() {
    _ensureShared();
    putOrReenter(
      () => SilHousesController(Get.find<SilRepository>()),
      onReenter: (c) => c.onScreenReenter(),
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
    final args = routeArguments();
    String? houseId = routeParam('id') ?? routeParam('house_id');
    if (args is Map) {
      houseId ??= args['house_id']?.toString() ?? args['id']?.toString();
    } else if (args != null) {
      houseId ??= args.toString();
    }
    if (houseId == null || houseId.isEmpty) {
      throw StateError('sil house detail requires house_id');
    }
    final resolvedHouseId = houseId;
    // lazyPut kept the first houseId forever under GoRouter; always recreate.
    putFresh(
      () => SilHouseDetailController(
        Get.find<SilRepository>(),
        houseId: resolvedHouseId,
      ),
    );
  }
}
