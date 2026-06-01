import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../models/attendance/employee_model.dart';
import '../../models/attendance/employee_role_option.dart';
import '../../models/attendance/employee_update_request.dart';
import '../../models/attendance/time_entry_out.dart';
import '../../models/payroll/payroll_date_utils.dart';

class EmployeeRemoteDataSource {
  EmployeeRemoteDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<EmployeeModel>> listEmployees() async {
    final response = await _dio.get<List<dynamic>>('/v1/employees');
    final data = response.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmployeeModel.fromJson)
        .toList();
  }

  Future<List<EmployeeModel>> listEmployeesWithClockStatus() async {
    final response = await _dio.get<List<dynamic>>(
      '/v1/employees/clocked-in-status',
      queryParameters: {'branch_id': AppConstants.branchId},
    );
    final data = response.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmployeeModel.fromJson)
        .toList();
  }

  Future<EmployeeModel> getEmployee(String employeeId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/employees/$employeeId',
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Invalid employee response format.',
      );
    }
    return EmployeeModel.fromJson(data);
  }

  Future<EmployeeModel> updateEmployee(
    String employeeId,
    EmployeeUpdateRequest body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/v1/employees/$employeeId',
      data: body.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Invalid employee update response format.',
      );
    }
    return EmployeeModel.fromJson(data);
  }

  Future<List<EmployeeRoleOption>> listRoleOptions() async {
    final response = await _dio.get<List<dynamic>>('/v1/employees/role-options');
    final data = response.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmployeeRoleOption.fromJson)
        .toList();
  }

  Future<List<TimeEntryOut>> listTimeEntries({
    required String employeeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/v1/attendance/time-entries',
      queryParameters: {
        'employee_id': employeeId,
        'from': fmtPayrollDate(from),
        'to': fmtPayrollDate(to),
      },
    );
    final data = response.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(TimeEntryOut.fromJson)
        .toList();
  }

  Future<String> resetEmployeePin(String employeeId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/employees/$employeeId/reset-pin',
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Invalid reset PIN response format.',
      );
    }
    return data['message'] as String? ?? 'PIN reset requested.';
  }
}
