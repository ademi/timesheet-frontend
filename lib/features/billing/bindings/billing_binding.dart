import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../visits/bindings/visits_binding.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/invoice_export_detail_controller.dart';
import '../controllers/invoice_exports_controller.dart';
import '../data/datasources/billing_remote_datasource.dart';
import '../data/datasources/ndis_catalogue_remote_datasource.dart';
import '../data/repositories/billing_repository.dart';
import '../data/repositories/ndis_catalogue_repository.dart';

/// Registers billing + NDIS catalogue data layer (Phase 5 UI uses these).
class BillingBinding extends Bindings {
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

class StaffInvoiceExportsBinding extends Bindings {
  @override
  void dependencies() {
    BillingBinding.ensureShared();
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<InvoiceExportsController>()) {
      Get.put(
        InvoiceExportsController(
          repository: Get.find<BillingRepository>(),
          visitsRepository: Get.find<VisitsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}

class StaffInvoiceExportDetailBinding extends Bindings {
  @override
  void dependencies() {
    BillingBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<InvoiceExportDetailController>()) {
      Get.put(
        InvoiceExportDetailController(
          repository: Get.find<BillingRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}
