import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/contractor_profile_controller.dart';
import '../controllers/staff_compliance_controller.dart';
import '../data/datasources/compliance_ops_remote_datasource.dart';
import '../data/repositories/compliance_ops_repository.dart';
import '../views/home_alerts_view.dart';

class ComplianceOpsBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
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
    if (!Get.isRegistered<ComplianceOpsRemoteDataSource>()) {
      Get.lazyPut<ComplianceOpsRemoteDataSource>(
        () => ComplianceOpsRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ComplianceOpsRepository>()) {
      Get.lazyPut<ComplianceOpsRepository>(
        () => ComplianceOpsRepository(
          remote: Get.find<ComplianceOpsRemoteDataSource>(),
        ),
        fenix: true,
      );
    }
  }
}

class StaffComplianceBinding extends Bindings {
  @override
  void dependencies() {
    ComplianceOpsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<StaffComplianceController>()) {
      Get.put(
        StaffComplianceController(
          repository: Get.find<ComplianceOpsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}

class ContractorProfileOpsBinding extends Bindings {
  @override
  void dependencies() {
    ComplianceOpsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ContractorProfileController>()) {
      Get.put(
        ContractorProfileController(
          repository: Get.find<ComplianceOpsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}

class HomeAlertsBinding extends Bindings {
  @override
  void dependencies() {
    ComplianceOpsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (Get.isRegistered<HomeAlertsController>()) {
      Get.delete<HomeAlertsController>();
    }
    Get.put(
      HomeAlertsController(
        repository: Get.find<ComplianceOpsRepository>(),
        session: Get.find<SessionService>(),
      ),
    );
  }
}
