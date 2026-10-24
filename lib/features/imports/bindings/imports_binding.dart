import 'package:get/get.dart';

import '../../../core/getx/put_fresh.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/csv_import_controller.dart';
import '../data/datasources/imports_remote_datasource.dart';
import '../data/models/import_models.dart';
import '../data/repositories/imports_repository.dart';

class ImportsBinding extends Bindings {
  ImportsBinding({required this.kind});

  final ImportKind kind;

  @override
  void dependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<ImportsRemoteDataSource>()) {
      Get.lazyPut<ImportsRemoteDataSource>(
        () => ImportsRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ImportsRepository>()) {
      Get.lazyPut<ImportsRepository>(
        () => ImportsRepository(remote: Get.find<ImportsRemoteDataSource>()),
        fenix: true,
      );
    }
    // Tier-3: kind differs per route; always fresh controller.
    putFresh(
      () => CsvImportController(
        repository: Get.find<ImportsRepository>(),
        kind: kind,
      ),
    );
  }
}
