import 'package:dio/dio.dart';

import '../datasources/remote/attendance_remote_datasource.dart';
import '../models/attendance/attendance_request_model.dart';
import '../models/attendance/attendance_response_model.dart';
import '../models/attendance/employee_model.dart';

class AttendanceRepository {
  AttendanceRepository({required AttendanceRemoteDataSource remote})
      : _remote = remote;

  final AttendanceRemoteDataSource _remote;

  Future<List<EmployeeModel>> fetchEmployees() async {
    try {
      return await _remote.getEmployees();
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
}
