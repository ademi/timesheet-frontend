import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/contractor_register_models.dart';

class ContractorRegisterRemoteDataSource {
  ContractorRegisterRemoteDataSource({required Dio plainDio}) : _dio = plainDio;

  final Dio _dio;

  Future<ContractorInvitePublicOut> getPublicInvite(String token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.publicContractorInvite(token),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty contractor invite response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return ContractorInvitePublicOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ContractorRegisterResponse> register(
    ContractorRegisterRequest request,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.contractorsRegister,
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty register response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return ContractorRegisterResponse.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
