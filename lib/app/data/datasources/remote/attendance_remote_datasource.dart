import 'package:dio/dio.dart';

import '../../models/attendance/attendance_error_model.dart';
import '../../models/attendance/attendance_request_model.dart';
import '../../models/attendance/attendance_response_model.dart';
import '../../models/attendance/employee_model.dart';

AttendanceErrorModel? parseAttendanceError(DioException e) {
  final data = e.response?.data;
  if (data is Map<String, dynamic>) {
    return AttendanceErrorModel.fromJson(data);
  }
  return null;
}

class AttendanceRemoteDataSource {
  AttendanceRemoteDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<EmployeeModel>> getEmployees({String? branchId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/v1/employees/clocked-in-status',
      queryParameters: branchId != null ? {'branch_id': branchId} : null,
    );
    final data = response.data;
    if (data == null) return [];
    return data
        .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AttendanceResponseModel> clockIn(AttendanceRequestModel body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/attendance/clock-in',
      data: body.toJson(),
    );
    final map = response.data;
    if (map == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty clock-in response',
      );
    }
    return AttendanceResponseModel.fromJson(map);
  }

  Future<AttendanceResponseModel> clockOut(AttendanceRequestModel body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/attendance/clock-out',
      data: body.toJson(),
    );
    final map = response.data;
    if (map == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty clock-out response',
      );
    }
    return AttendanceResponseModel.fromJson(map);
  }
}
