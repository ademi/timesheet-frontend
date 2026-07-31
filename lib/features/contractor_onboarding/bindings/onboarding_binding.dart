import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../../credentials/controllers/credentials_controller.dart';
import '../../engagements/controllers/contractor_engagements_controller.dart';
import '../controllers/onboarding_controller.dart';
import '../data/datasources/compliance_remote_datasource.dart';
import '../data/repositories/compliance_repository.dart';

class OnboardingBinding extends Bindings {
  @override
  void dependencies() => ensure();

  /// Idempotent registration for the onboarding funnel.
  ///
  /// Funnel controllers are permanent so GetX smart-management does not delete
  /// them when `_syncRoute` replaces `/contractor/onboarding/*` steps with
  /// `Get.offNamed` (each step is its own GetPage).
  static void ensure() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
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
    if (!Get.isRegistered<OnboardingController>()) {
      Get.put<OnboardingController>(
        OnboardingController(repository: Get.find<ComplianceRepository>()),
        permanent: true,
      );
    }
  }

  /// Drop permanent funnel controllers (finish / logout).
  static void reset() {
    if (Get.isRegistered<OnboardingController>()) {
      Get.delete<OnboardingController>(force: true);
    }
    if (Get.isRegistered<ContractorEngagementsController>()) {
      Get.delete<ContractorEngagementsController>(force: true);
    }
    if (Get.isRegistered<CredentialsController>()) {
      Get.delete<CredentialsController>(force: true);
    }
  }
}
