import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/contractor_me_models.dart';

class ContractorMeRemoteDataSource {
  ContractorMeRemoteDataSource({required Dio authenticatedDio})
    : _dio = authenticatedDio;

  final Dio _dio;

  Future<ContractorMeOut> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.contractorMe,
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_contractor_me',
          message: 'Empty contractor profile response',
          presentation: AppFailurePresentation.inline,
        );
      }
      return ContractorMeOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ContractorMeOut> patchMe({
    String? fullName,
    String? phone,
    String? dob,
    String? abn,
  }) async {
    try {
      final body = <String, dynamic>{
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (dob != null) 'dob': dob,
        if (abn != null) 'abn': abn,
      };
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.contractorMe,
        data: body,
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_contractor_me',
          message: 'Empty contractor profile response',
          presentation: AppFailurePresentation.inline,
        );
      }
      return ContractorMeOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ContractorMeOut> putPaymentDetails(
    ContractorPaymentDetailsIn body,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiPaths.contractorMePaymentDetails,
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_contractor_me',
          message: 'Empty contractor profile response',
          presentation: AppFailurePresentation.inline,
        );
      }
      return ContractorMeOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ContractorMeOut> deletePaymentDetails() async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        ApiPaths.contractorMePaymentDetails,
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_contractor_me',
          message: 'Empty contractor profile response',
          presentation: AppFailurePresentation.inline,
        );
      }
      return ContractorMeOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
