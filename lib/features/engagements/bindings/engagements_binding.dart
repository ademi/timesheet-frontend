import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../credentials/bindings/credentials_binding.dart';
import '../../credentials/data/repositories/credentials_repository.dart';
import '../../contractor_onboarding/data/datasources/compliance_remote_datasource.dart';
import '../../contractor_onboarding/data/repositories/compliance_repository.dart';
import '../../payroll/bindings/payroll_binding.dart';
import '../../payroll/controllers/engagement_rate_bands_controller.dart';
import '../../payroll/data/repositories/payroll_repository.dart';
import '../../visits/bindings/visits_binding.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../controllers/contractor_engagements_controller.dart';
import '../controllers/workforce_controller.dart';
import '../data/datasources/engagements_remote_datasource.dart';
import '../data/repositories/engagements_repository.dart';

class EngagementsBinding extends Bindings {
  @override
  void dependencies() {
    ensureShared();
    CredentialsBinding.ensureDependencies();
    PayrollBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<EngagementRateBandsController>()) {
      Get.put(
        EngagementRateBandsController(
          payroll: Get.find<PayrollRepository>(),
          session: Get.find<SessionService>(),
        ),
      );
    }
    if (!Get.isRegistered<WorkforceController>()) {
      Get.put(
        WorkforceController(
          repository: Get.find<EngagementsRepository>(),
          credentialsRepository: Get.find<CredentialsRepository>(),
          session: Get.find<SessionService>(),
          visits: Get.find<VisitsRepository>(),
        ),
      );
    }
  }

  static void ensureShared() {
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
    if (!Get.isRegistered<EngagementsRemoteDataSource>()) {
      Get.lazyPut<EngagementsRemoteDataSource>(
        () => EngagementsRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<EngagementsRepository>()) {
      Get.lazyPut<EngagementsRepository>(
        () => EngagementsRepository(
          remote: Get.find<EngagementsRemoteDataSource>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ComplianceRemoteDataSource>()) {
      Get.lazyPut<ComplianceRemoteDataSource>(
        () => ComplianceRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ComplianceRepository>()) {
      Get.lazyPut<ComplianceRepository>(
        () => ComplianceRepository(
          remote: Get.find<ComplianceRemoteDataSource>(),
        ),
        fenix: true,
      );
    }
  }
}

class ContractorEngagementsBinding extends Bindings {
  @override
  void dependencies() => ensure();

  /// [permanent] keeps the controller across onboarding step `Get.offNamed`
  /// replacements (same pattern as [OnboardingController]).
  static void ensure({bool permanent = false}) {
    EngagementsBinding.ensureShared();
    if (!Get.isRegistered<ContractorEngagementsController>()) {
      if (!Get.isRegistered<SessionService>()) return;
      Get.put(
        ContractorEngagementsController(
          repository: Get.find<EngagementsRepository>(),
          complianceRepository: Get.find<ComplianceRepository>(),
          session: Get.find<SessionService>(),
        ),
        permanent: permanent,
      );
    }
  }
}
