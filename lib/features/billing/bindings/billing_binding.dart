import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../visits/bindings/visits_binding.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../controllers/staff_invoices_controller.dart';
import '../data/datasources/billing_remote_datasource.dart';
import '../data/repositories/billing_repository.dart';

class BillingBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
  }

  static void ensureShared() {
    VisitsBinding.ensureShared();
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

class StaffInvoicesBinding extends Bindings {
  @override
  void dependencies() {
    BillingBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<StaffInvoicesController>()) {
      Get.put(
        StaffInvoicesController(
          billing: Get.find<BillingRepository>(),
          visits: Get.find<VisitsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}
