import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../clients/bindings/clients_binding.dart';
import '../../engagements/bindings/engagements_binding.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../billing/bindings/billing_binding.dart';
import '../../payroll/bindings/payroll_binding.dart';
import '../../payroll/data/repositories/payroll_repository.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../controllers/jobs_controller.dart';
import '../controllers/ongoing_support_controller.dart';
import '../controllers/unified_support_controller.dart';
import '../data/datasources/jobs_remote_datasource.dart';
import '../data/repositories/jobs_repository.dart';
import '../../shifts/data/repositories/shifts_repository.dart';
import '../../visits/bindings/visits_binding.dart';
import '../../visits/data/repositories/visits_repository.dart';

class JobsBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<JobsController>()) {
      Get.put(
        JobsController(
          repository: Get.find<JobsRepository>(),
          clientsRepository: Get.find<ClientsRepository>(),
          engagementsRepository: Get.find<EngagementsRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
  }

  static void ensureShared() {
    ClientsBinding.ensureShared();
    EngagementsBinding.ensureShared();
    BillingBinding.ensureShared();
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<JobsRemoteDataSource>()) {
      Get.lazyPut<JobsRemoteDataSource>(
        () => JobsRemoteDataSource(authenticatedDio: Get.find<ApiClient>().dio),
        fenix: true,
      );
    }
    if (!Get.isRegistered<JobsRepository>()) {
      Get.lazyPut<JobsRepository>(
        () => JobsRepository(remote: Get.find<JobsRemoteDataSource>()),
        fenix: true,
      );
    }
  }
}

class OngoingSupportBinding extends Bindings {
  @override
  void dependencies() {
    JobsBinding.ensureShared();
    BillingBinding.ensureShared();
    PayrollBinding.ensureShared();
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    Get.put(
      OngoingSupportController(
        jobsRepository: Get.find<JobsRepository>(),
        clientsRepository: Get.find<ClientsRepository>(),
        engagementsRepository: Get.find<EngagementsRepository>(),
        session: Get.find<SessionService>(),
        payroll: Get.isRegistered<PayrollRepository>()
            ? Get.find<PayrollRepository>()
            : null,
      ),
    );
  }
}

class UnifiedSupportBinding extends Bindings {
  @override
  void dependencies() {
    JobsBinding.ensureShared();
    BillingBinding.ensureShared();
    PayrollBinding.ensureShared();
    VisitsBinding.ensureShared();
    ClientsBinding().dependencies();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ShiftsRepository>()) return;
    Get.put(
      UnifiedSupportController(
        jobsRepository: Get.find<JobsRepository>(),
        clientsRepository: Get.find<ClientsRepository>(),
        engagementsRepository: Get.find<EngagementsRepository>(),
        shiftsRepository: Get.find<ShiftsRepository>(),
        visitsRepository: Get.find<VisitsRepository>(),
        session: Get.find<SessionService>(),
        payroll: Get.isRegistered<PayrollRepository>()
            ? Get.find<PayrollRepository>()
            : null,
      ),
    );
  }
}
