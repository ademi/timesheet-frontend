import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/schedule_models.dart';

class ContractorScheduleRemoteDataSource {
  ContractorScheduleRemoteDataSource({required Dio authenticatedDio})
      : _dio = authenticatedDio;

  final Dio _dio;

  Future<TimetableOut> getTimetable({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.contractorMeTimetable,
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty timetable response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return TimetableOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<AvailabilityRuleOut>> listAvailability() async {
    try {
      final response = await _dio.get<dynamic>(ApiPaths.contractorMeAvailability);
      return _parseAvailability(response.data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<AvailabilityRuleOut>> putAvailability(
    List<AvailabilityRuleOut> rules,
  ) async {
    try {
      final response = await _dio.put<dynamic>(
        ApiPaths.contractorMeAvailability,
        data: {
          'rules': [for (final r in rules) r.toRuleJson()],
        },
      );
      return _parseAvailability(response.data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<LeaveOut>> listLeave() async {
    try {
      final response = await _dio.get<List<dynamic>>(ApiPaths.contractorMeLeave);
      return _mapList(response.data, LeaveOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<LeaveOut> createLeave(LeaveCreateRequest body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.contractorMeLeave,
        data: body.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Empty leave create response',
          presentation: AppFailurePresentation.toast,
        );
      }
      return LeaveOut.fromJson(data);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<void> deleteLeave(String id) async {
    try {
      await _dio.delete<void>(ApiPaths.contractorMeLeaveItem(id));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  List<AvailabilityRuleOut> _parseAvailability(dynamic data) {
    if (data is List) {
      return _mapList(data, AvailabilityRuleOut.fromJson);
    }
    if (data is Map) {
      final rules = data['rules'] ?? data['availability'] ?? data['items'];
      if (rules is List) {
        return _mapList(rules, AvailabilityRuleOut.fromJson);
      }
    }
    return const [];
  }

  List<T> _mapList<T>(
    List<dynamic>? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = raw ?? const [];
    return list
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
