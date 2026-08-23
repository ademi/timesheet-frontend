import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/billing_models.dart';

class NdisCatalogueRemoteDataSource {
  NdisCatalogueRemoteDataSource({required Dio authenticatedDio})
      : _dio = authenticatedDio;

  final Dio _dio;

  Future<NdisCatalogueSearchResponse> searchItems({
    required String q,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.ndisCatalogueItems,
        queryParameters: {
          'q': q.trim(),
          'limit': limit,
        },
      );
      final data = response.data;
      if (data == null) {
        throw AppFailure(
          code: 'unknown',
          message: 'Empty catalogue search response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return NdisCatalogueSearchResponse.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
