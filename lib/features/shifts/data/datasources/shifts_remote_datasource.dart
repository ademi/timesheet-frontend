import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../jobs/data/models/job_models.dart';
import '../models/shift_models.dart';

class ShiftsRemoteDataSource {
  ShiftsRemoteDataSource({required Dio authenticatedDio}) : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<ShiftOut>> listShifts({
    DateTime? from,
    DateTime? to,
    String? jobId,
    int limit = 200,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.shifts,
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (jobId != null && jobId.isNotEmpty) 'job_id': jobId,
          'limit': limit,
        },
      );
      return _mapList(response.data, ShiftOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<OpenShiftOut>> listOpenShifts({
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.shiftsOpen,
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          'limit': limit,
        },
      );
      return _mapList(response.data, OpenShiftOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> getShift(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiPaths.shift(id));
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> createShift(ShiftCreateRequest body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shifts,
        data: body.toJson(),
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> publishShift(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftPublish(id),
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> assignShift({
    required String shiftId,
    required String contractorId,
    List<TaskTemplateItem>? taskTemplate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftAssign(shiftId),
        data: {
          'contractor_id': contractorId,
          if (taskTemplate != null && taskTemplate.isNotEmpty)
            'task_template': [for (final task in taskTemplate) task.toJson()],
        },
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> unassignShift(String shiftId, String contractorId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftUnassign(shiftId),
        data: {'contractor_id': contractorId},
      );
      return ShiftOut.fromJson(_require(response.data));
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> claimShift(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftClaim(id),
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<ShiftOut> cancelShift(String id) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.shiftCancel(id),
      );
      return ShiftOut.fromJson(response.data!);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  List<T> _mapList<T>(
    List<dynamic>? data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data == null) return const [];
    return data
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Map<String, dynamic> _require(Map<String, dynamic>? data) {
    if (data == null) {
      throw const AppFailure(
        code: 'unknown',
        message: 'Empty shift response',
        presentation: AppFailurePresentation.toast,
      );
    }
    return data;
  }
}
