import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../engagements/bindings/engagements_binding.dart';
import '../../compliance_ops/bindings/compliance_ops_binding.dart';
import '../../compliance_ops/data/repositories/compliance_ops_repository.dart';
import '../../visits/bindings/visits_binding.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../controllers/contractor_payments_controller.dart';
import '../controllers/staff_payments_controller.dart';
import '../controllers/staff_tenant_settings_controller.dart';
import '../data/datasources/payroll_remote_datasource.dart';
import '../data/repositories/payroll_repository.dart';

class PayrollBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
  }

  static void ensureShared() {
    EngagementsBinding.ensureShared();
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
    if (!Get.isRegistered<PayrollRemoteDataSource>()) {
      Get.lazyPut<PayrollRemoteDataSource>(
        () => PayrollRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<PayrollRepository>()) {
      Get.lazyPut<PayrollRepository>(
        () => PayrollRepository(remote: Get.find<PayrollRemoteDataSource>()),
        fenix: true,
      );
    }
  }
}

class StaffPaymentsBinding extends Bindings {
  @override
  void dependencies() {
    PayrollBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<StaffPaymentsController>()) {
      Get.put(
        StaffPaymentsController(
          payroll: Get.find<PayrollRepository>(),
          visits: Get.find<VisitsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}

class ContractorPaymentsBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ContractorPaymentsController>()) {
      Get.put(
        ContractorPaymentsController(
          visits: Get.find<VisitsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}

class StaffTenantSettingsBinding extends Bindings {
  @override
  void dependencies() {
    PayrollBinding.ensureShared();
    ComplianceOpsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<StaffTenantSettingsController>()) {
      Get.put(
        StaffTenantSettingsController(
          payroll: Get.find<PayrollRepository>(),
          complianceOps: Get.find<ComplianceOpsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }
}
