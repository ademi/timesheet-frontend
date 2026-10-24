import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/feedback_models.dart';

class FeedbackRemoteDataSource {
  FeedbackRemoteDataSource({required Dio authenticatedDio})
    : _dio = authenticatedDio;

  final Dio _dio;

  Future<FeedbackOut> submit(FeedbackCreateRequest body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.feedback,
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty feedback response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return FeedbackOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<FeedbackOut>> list({int limit = 50}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.feedback,
        queryParameters: {'limit': limit},
      );
      final raw = response.data ?? const [];
      return raw
          .whereType<Map>()
          .map((e) => FeedbackOut.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
