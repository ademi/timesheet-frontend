import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import 'feature_flags_models.dart';

class FeatureFlagsRepository {
  FeatureFlagsRepository({required Dio plainDio}) : _dio = plainDio;

  final Dio _dio;

  PublicFeatureFlags? _cached;
  DateTime? _cachedAt;
  static const _ttl = Duration(minutes: 5);

  Future<PublicFeatureFlags> load({bool force = false}) async {
    if (!force &&
        _cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _ttl) {
      return _cached!;
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.publicFeatureFlags,
      );
      final data = response.data;
      final flags =
          data == null
              ? PublicFeatureFlags.empty
              : PublicFeatureFlags.fromJson(data);
      _cached = flags;
      _cachedAt = DateTime.now();
      return flags;
    } catch (_) {
      return _cached ?? PublicFeatureFlags.empty;
    }
  }

  static FeatureFlagsRepository ensureRegistered() {
    if (Get.isRegistered<FeatureFlagsRepository>()) {
      return Get.find<FeatureFlagsRepository>();
    }
    if (!Get.isRegistered<ApiClient>()) {
      return FeatureFlagsRepository(plainDio: Dio());
    }
    final repo = FeatureFlagsRepository(
      plainDio: Get.find<ApiClient>().plainDio,
    );
    Get.put(repo, permanent: true);
    return repo;
  }
}
