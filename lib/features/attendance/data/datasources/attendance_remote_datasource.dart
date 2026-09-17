import 'package:dio/dio.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/app_failure.dart';
import '../attendance_review_models.dart';

class AttendanceRemoteDataSource {
  AttendanceRemoteDataSource({required Dio authenticatedDio})
    : _dio = authenticatedDio;

  final Dio _dio;

  Future<List<AttendanceExceptionOut>> listExceptions({String? status}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.attendanceExceptions,
        queryParameters: {if (status != null) 'status': status},
      );
      return _mapList(response.data, AttendanceExceptionOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<AttendanceExceptionOut> ackException(
    String exceptionId, {
    required String decision,
    String? note,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.attendanceExceptionAck(exceptionId),
        data: {
          'decision': decision,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      return _require(
        response.data,
        AttendanceExceptionOut.fromJson,
        'ack exception',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<List<AttendanceSyncConflictOut>> listSyncConflicts({
    String? status,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.attendanceSyncConflicts,
        queryParameters: {if (status != null) 'status': status},
      );
      return _mapList(response.data, AttendanceSyncConflictOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<AttendanceSyncConflictOut> forceAcceptSyncConflict(
    String conflictId, {
    required String note,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.attendanceSyncConflictForceAccept(conflictId),
        data: {'note': note},
      );
      return _require(
        response.data,
        AttendanceSyncConflictOut.fromJson,
        'force-accept conflict',
      );
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }

  Future<AttendanceSyncConflictOut> discardSyncConflict(
    String conflictId, {
    required String note,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiPaths.attendanceSyncConflictDiscard(conflictId),
        data: {'note': note},
      );
      return _require(
        response.data,
        AttendanceSyncConflictOut.fromJson,
        'discard conflict',
      );
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
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  T _require<T>(
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>) fromJson,
    String label,
  ) {
    if (data == null) {
      throw AppFailure(
        code: 'unknown',
        message: 'Empty response for $label',
        presentation: AppFailurePresentation.toast,
      );
    }
    return fromJson(data);
  }
}
