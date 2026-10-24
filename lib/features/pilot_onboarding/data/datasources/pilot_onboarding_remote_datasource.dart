import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/pilot_onboarding_models.dart';

class PilotOnboardingRemoteDataSource {
  PilotOnboardingRemoteDataSource({required Dio authenticatedDio})
    : _dio = authenticatedDio;

  final Dio _dio;

  Future<PilotOnboardingOut> getStatus() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.pilotOnboarding,
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty pilot-onboarding response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return PilotOnboardingOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<PilotOnboardingOut> dismiss() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.pilotOnboardingDismiss,
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty pilot-onboarding dismiss response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return PilotOnboardingOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
