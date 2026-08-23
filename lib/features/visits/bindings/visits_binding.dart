import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../billing/bindings/billing_binding.dart';
import '../../engagements/bindings/engagements_binding.dart';
import '../../payroll/bindings/payroll_binding.dart';
import '../../payroll/data/repositories/payroll_repository.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../jobs/bindings/jobs_binding.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../shifts/data/datasources/shifts_remote_datasource.dart';
import '../../shifts/data/repositories/shifts_repository.dart';
import '../controllers/contractor_visits_controller.dart';
import '../controllers/staff_visits_controller.dart';
import '../data/datasources/visits_remote_datasource.dart';
import '../data/repositories/visits_repository.dart';
import '../services/visit_location_service.dart';

class VisitsBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
  }

  static void ensureShared() {
    BillingBinding.ensureShared();
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<VisitsRemoteDataSource>()) {
      Get.lazyPut<VisitsRemoteDataSource>(
        () =>
            VisitsRemoteDataSource(authenticatedDio: Get.find<ApiClient>().dio),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VisitsRepository>()) {
      Get.lazyPut<VisitsRepository>(
        () => VisitsRepository(remote: Get.find<VisitsRemoteDataSource>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ShiftsRemoteDataSource>()) {
      Get.lazyPut<ShiftsRemoteDataSource>(
        () =>
            ShiftsRemoteDataSource(authenticatedDio: Get.find<ApiClient>().dio),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ShiftsRepository>()) {
      Get.lazyPut<ShiftsRepository>(
        () => ShiftsRepository(remote: Get.find<ShiftsRemoteDataSource>()),
        fenix: true,
      );
    }
    if (!Get.isRegistered<VisitLocationService>()) {
      Get.put<VisitLocationService>(const VisitLocationService());
    }
  }
}

class StaffVisitsBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    JobsBinding.ensureShared();
    EngagementsBinding.ensureShared();
    PayrollBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<StaffVisitsController>()) {
      Get.put(
        StaffVisitsController(
          repository: Get.find<VisitsRepository>(),
          shiftsRepository: Get.find<ShiftsRepository>(),
          jobsRepository: Get.find<JobsRepository>(),
          engagementsRepository: Get.find<EngagementsRepository>(),
          session: Get.find<SessionService>(),
          payroll: Get.isRegistered<PayrollRepository>()
              ? Get.find<PayrollRepository>()
              : null,
        ),
      );
    }
  }
}

class ContractorVisitsBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ContractorVisitsController>()) {
      Get.put(
        ContractorVisitsController(
          repository: Get.find<VisitsRepository>(),
          shiftsRepository: Get.find<ShiftsRepository>(),
          session: Get.find<SessionService>(),
          location: Get.find<VisitLocationService>(),
        ),
      );
    }
  }
}
