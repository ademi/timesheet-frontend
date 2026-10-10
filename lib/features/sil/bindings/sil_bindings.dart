import 'package:get/get.dart';

import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../core/getx/put_fresh.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../../clients/data/datasources/clients_remote_datasource.dart';
import '../../clients/data/repositories/clients_repository.dart';
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

  /// Clients list for the house-member picker (no full ClientsBinding graph).
  static void _ensureClientsForPicker() {
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

class SilHouseDetailBinding extends Bindings {
  @override
  void dependencies() {
    SilHousesBinding._ensureShared();
    SilHousesBinding._ensureClientsForPicker();
    final resolvedHouseId = _resolveHouseId();
    if (resolvedHouseId == null) {
      throw StateError('sil house detail requires house_id');
    }
    // lazyPut kept the first houseId forever under GoRouter; always recreate.
    putFresh(
      () => SilHouseDetailController(
        Get.find<SilRepository>(),
        houseId: resolvedHouseId,
        clientsRepository: Get.find<ClientsRepository>(),
      ),
    );
  }

  /// Prefer query/path params (synced in the GoRoute builder), then `extra`.
  static String? _resolveHouseId() {
    final fromRoute = routeParam('id') ?? routeParam('house_id');
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;

    final args = routeArguments();
    if (args is Map) {
      final fromMap =
          args['house_id']?.toString() ?? args['id']?.toString();
      if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    } else if (args is String && args.isNotEmpty) {
      return args;
    }
    return null;
  }
}
