import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/sil_models.dart';

class SilRemoteDataSource {
  SilRemoteDataSource({required Dio authenticatedDio}) : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<SilHouseOut>> listHouses() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiPaths.silHouses);
      final data = response.data ?? const [];
      return [
        for (final item in data)
          if (item is Map)
            SilHouseOut.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<SilHouseOut> createHouse(SilHouseCreateRequest body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.silHouses,
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_response',
          message: 'create sil house: empty',
          presentation: AppFailurePresentation.toast,
        );
      }
      return SilHouseOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<SilHouseBundleOut> getHouse(String houseId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.silHouse(houseId),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_response',
          message: 'get sil house: empty',
          presentation: AppFailurePresentation.toast,
        );
      }
      return SilHouseBundleOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<SilHouseMemberOut> upsertMember(
    String houseId,
    SilHouseMemberUpsertRequest body,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiPaths.silHouseMembers(houseId),
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_response',
          message: 'upsert member: empty',
          presentation: AppFailurePresentation.toast,
        );
      }
      return SilHouseMemberOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<SilRocBlockOut> upsertRocBlock(
    String houseId,
    SilRocBlockUpsertRequest body,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiPaths.silHouseRocBlocks(houseId),
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_response',
          message: 'upsert roc: empty',
          presentation: AppFailurePresentation.toast,
        );
      }
      return SilRocBlockOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> linkJobHouse(String jobId, String? silHouseId) async {
    try {
      await _dio.put(
        ApiPaths.jobSilHouse(jobId),
        data: {'sil_house_id': silHouseId},
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<SilHouseOut> patchHouse(
    String houseId,
    SilHousePatchRequest body,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiPaths.silHouse(houseId),
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_response',
          message: 'patch sil house: empty',
          presentation: AppFailurePresentation.toast,
        );
      }
      return SilHouseOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<SilVacancyOverlayOut> getOverlay(String houseId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.silHouseOverlay(houseId),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_response',
          message: 'sil overlay: empty',
          presentation: AppFailurePresentation.toast,
        );
      }
      return SilVacancyOverlayOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<SilFillVacancyOut> fillVacancy(
    String houseId,
    SilFillVacancyRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.silHouseFillVacancy(houseId),
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_response',
          message: 'fill vacancy: empty',
          presentation: AppFailurePresentation.toast,
        );
      }
      return SilFillVacancyOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<SilCompatRuleOut>> listCompatRules(String houseId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.silHouseCompatRules(houseId),
      );
      final data = response.data ?? const [];
      return [
        for (final item in data)
          if (item is Map)
            SilCompatRuleOut.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<SilCompatRuleOut> createCompatRule(
    String houseId,
    SilCompatRuleCreateRequest body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.silHouseCompatRules(houseId),
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'empty_response',
          message: 'create compat rule: empty',
          presentation: AppFailurePresentation.toast,
        );
      }
      return SilCompatRuleOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> deleteCompatRule(String houseId, String ruleId) async {
    try {
      await _dio.delete(ApiPaths.silHouseCompatRule(houseId, ruleId));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
}
