import 'package:dio/dio.dart';

import '../../../core/services/token_storage.dart';
import '../datasources/remote/attendance_remote_datasource.dart';
import '../models/attendance/attendance_adjustment_history.dart';
import '../models/attendance/attendance_adjustment_request.dart';
import '../models/attendance/attendance_adjustment_response.dart';
import '../models/attendance/attendance_exception_model.dart';
import '../models/attendance/attendance_request_model.dart';
import '../models/attendance/attendance_response_model.dart';
import '../models/attendance/employee_model.dart';

class AttendanceRepository {
  AttendanceRepository({
    required AttendanceRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  final AttendanceRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  Future<List<EmployeeModel>> fetchEmployees() async {
    try {
      return await _remote.getEmployees(branchId: _tokenStorage.branchId);
    } on DioException catch (e) {
      final parsed = parseAttendanceError(e);
      if (parsed != null) throw parsed;
      rethrow;
    }
  }

  Future<AttendanceResponseModel> clockIn(AttendanceRequestModel request) async {
    try {
      return await _remote.clockIn(request);
    } on DioException catch (e) {
      final parsed = parseAttendanceError(e);
      if (parsed != null) throw parsed;
      rethrow;
    }
  }

  Future<AttendanceResponseModel> clockOut(AttendanceRequestModel request) async {
    try {
      return await _remote.clockOut(request);
    } on DioException catch (e) {
      final parsed = parseAttendanceError(e);
      if (parsed != null) throw parsed;
      rethrow;
    }
  }

  Future<List<AttendanceExceptionModel>> fetchExceptions({
    required String from,
    required String to,
    bool useBranchFilter = true,
  }) async {
    try {
      return await _remote.getExceptions(
        from: from,
        to: to,
        branchId: useBranchFilter ? _tokenStorage.branchId : null,
      );
    } on DioException catch (e) {
      final parsed = parseAttendanceError(e);
      if (parsed != null) throw parsed;
      rethrow;
    }
  }

  Future<AttendanceAdjustmentResponse> submitAdjustment(
    AttendanceAdjustmentRequest request,
  ) async {
    try {
      return await _remote.postAdjustment(request);
    } on DioException catch (e) {
      final parsed = parseAttendanceError(e);
      if (parsed != null) throw parsed;
      rethrow;
    }
  }

  Future<List<AttendanceAdjustmentHistory>> fetchAdjustmentHistory(
    String timeEntryId,
  ) async {
    try {
      return await _remote.getAdjustmentHistory(timeEntryId);
    } on DioException catch (e) {
      final parsed = parseAttendanceError(e);
      if (parsed != null) throw parsed;
      rethrow;
    }
  }
}
