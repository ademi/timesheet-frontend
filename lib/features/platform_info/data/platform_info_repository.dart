import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import 'platform_info_models.dart';

class PlatformInfoRepository {
  PlatformInfoRepository({required Dio plainDio}) : _dio = plainDio;

  final Dio _dio;

  PlatformInfoOut? _cached;
  DateTime? _cachedAt;
  static const _ttl = Duration(minutes: 10);

  Future<PlatformInfoOut> load({bool force = false}) async {
    if (!force &&
        _cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _ttl) {
      return _cached!;
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.publicPlatformInfo,
      );
      final data = response.data;
      final info =
          data == null
              ? PlatformInfoOut.empty
              : PlatformInfoOut.fromJson(data);
      _cached = info;
      _cachedAt = DateTime.now();
      return info;
    } catch (_) {
      return _cached ?? PlatformInfoOut.empty;
    }
  }

  static PlatformInfoRepository ensureRegistered() {
    if (Get.isRegistered<PlatformInfoRepository>()) {
      return Get.find<PlatformInfoRepository>();
    }
    if (!Get.isRegistered<ApiClient>()) {
      final repo = PlatformInfoRepository(plainDio: Dio());
      Get.put(repo, permanent: true);
      return repo;
    }
    final repo = PlatformInfoRepository(
      plainDio: Get.find<ApiClient>().plainDio,
    );
    Get.put(repo, permanent: true);
    return repo;
  }
}
