import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../clients/bindings/clients_binding.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../credentials/bindings/credentials_binding.dart';
import '../../credentials/data/repositories/credentials_repository.dart';
import '../../documents/data/document_pipeline.dart';
import '../../engagements/bindings/engagements_binding.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../jobs/bindings/jobs_binding.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../visits/bindings/visits_binding.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../controllers/contractor_profile_controller.dart';
import '../controllers/notifications_feed_controller.dart';
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
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
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
    CredentialsBinding.ensureDependencies();
    EngagementsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<StaffComplianceController>()) {
      Get.put(
        StaffComplianceController(
          repository: Get.find<ComplianceOpsRepository>(),
          credentialsRepository: Get.find<CredentialsRepository>(),
          engagementsRepository: Get.find<EngagementsRepository>(),
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
    CredentialsBinding.ensureDependencies();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ContractorProfileController>()) {
      Get.put(
        ContractorProfileController(
          repository: Get.find<ComplianceOpsRepository>(),
          session: Get.find<SessionService>(),
          documentPipeline: Get.isRegistered<DocumentPipeline>()
              ? Get.find<DocumentPipeline>()
              : null,
        ),
      );
    }
  }
}

class HomeAlertsBinding extends Bindings {
  @override
  void dependencies() {
    ComplianceOpsBinding.ensureShared();
    ClientsBinding.ensureShared();
    EngagementsBinding.ensureShared();
    JobsBinding.ensureShared();
    VisitsBinding.ensureShared();
    NotificationsFeedController.ensureRegistered();
    if (!Get.isRegistered<SessionService>()) return;
    // Keep across shell Get.offNamed tab switches to avoid refetch storms.
    if (!Get.isRegistered<HomeAlertsController>()) {
      Get.put(
        HomeAlertsController(
          repository: Get.find<ComplianceOpsRepository>(),
          session: Get.find<SessionService>(),
          clientsRepository: Get.find<ClientsRepository>(),
          engagementsRepository: Get.find<EngagementsRepository>(),
          jobsRepository: Get.find<JobsRepository>(),
          visitsRepository: Get.find<VisitsRepository>(),
          notificationsFeed: Get.find<NotificationsFeedController>(),
        ),
        permanent: true,
      );
    }
  }

  /// Drop permanent home controller on logout / tenant switch.
  static void reset() {
    if (Get.isRegistered<HomeAlertsController>()) {
      Get.delete<HomeAlertsController>(force: true);
    }
  }
}
