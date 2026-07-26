import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../../credentials/bindings/credentials_binding.dart';
import '../controllers/onboarding_controller.dart';
import '../data/datasources/compliance_remote_datasource.dart';
import '../data/repositories/compliance_repository.dart';

class OnboardingBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(
        ApiClient(Get.find<TokenStorage>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ComplianceRemoteDataSource>()) {
      Get.lazyPut<ComplianceRemoteDataSource>(
        () => ComplianceRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
      );
    }
    if (!Get.isRegistered<ComplianceRepository>()) {
      Get.lazyPut<ComplianceRepository>(
        () => ComplianceRepository(
          remote: Get.find<ComplianceRemoteDataSource>(),
        ),
      );
    }
    if (!Get.isRegistered<OnboardingController>()) {
      Get.put<OnboardingController>(
        OnboardingController(
          repository: Get.find<ComplianceRepository>(),
        ),
      );
    }
    // Credentials step (S3) shares compliance + document pipeline deps.
    CredentialsBinding().dependencies();
  }
}
