import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../data/datasources/billing_remote_datasource.dart';
import '../data/datasources/ndis_catalogue_remote_datasource.dart';
import '../data/repositories/billing_repository.dart';
import '../data/repositories/ndis_catalogue_repository.dart';

/// Registers billing + NDIS catalogue data layer (Phase 5 UI uses these).
class BillingBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }

    if (!Get.isRegistered<NdisCatalogueRemoteDataSource>()) {
      Get.lazyPut<NdisCatalogueRemoteDataSource>(
        () => NdisCatalogueRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<NdisCatalogueRepository>()) {
      Get.lazyPut<NdisCatalogueRepository>(
        () => NdisCatalogueRepository(
          remote: Get.find<NdisCatalogueRemoteDataSource>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<BillingRemoteDataSource>()) {
      Get.lazyPut<BillingRemoteDataSource>(
        () => BillingRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<BillingRepository>()) {
      Get.lazyPut<BillingRepository>(
        () => BillingRepository(remote: Get.find<BillingRemoteDataSource>()),
        fenix: true,
      );
    }
  }
}
