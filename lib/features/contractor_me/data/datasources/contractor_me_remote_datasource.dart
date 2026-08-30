import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../contractor_register/data/models/contractor_register_models.dart';
import '../models/contractor_me_models.dart';

class ContractorMeRemoteDataSource {
  ContractorMeRemoteDataSource({
    required Dio authenticatedDio,
    required Dio plainDio,
  })  : _dio = authenticatedDio,
        _plainDio = plainDio;

  final Dio _dio;
  final Dio _plainDio;

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
    String? addressLine1,
    String? addressLine2,
    String? suburb,
    String? state,
    String? postcode,
    String? country,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = <String, dynamic>{
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (dob != null) 'dob': dob,
        if (abn != null) 'abn': abn,
        if (addressLine1 != null) 'address_line1': addressLine1,
        if (addressLine2 != null) 'address_line2': addressLine2,
        if (suburb != null) 'suburb': suburb,
        if (state != null) 'state': state,
        if (postcode != null) 'postcode': postcode,
        if (country != null) 'country': country,
        if (metadata != null) 'metadata': metadata,
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

  Future<GeocodeResponse> geocode(GeocodeRequest body) async {
    try {
      final response = await _plainDio.post<Map<String, dynamic>>(
        ApiPaths.publicGeocode,
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_geocode',
          message: 'Empty geocode response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return GeocodeResponse.fromJson(data);
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
