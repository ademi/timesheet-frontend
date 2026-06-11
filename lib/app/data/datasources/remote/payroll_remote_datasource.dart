import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/attendance/employee_model.dart';
import '../../models/payroll/employee_balance_out.dart';
import '../../models/payroll/payroll_date_utils.dart';
import '../../models/payroll/period_create_request.dart';
import '../../models/payroll/period_out.dart';
import '../../models/payroll/rate_create_request.dart';
import '../../models/payroll/rate_out.dart';
import '../../models/payroll/result_out.dart';

class PayrollRemoteDataSource {
  PayrollRemoteDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<RateOut>> getRates(String employeeId) async {
    final response = await _dio.get('/v1/payroll/rates/$employeeId');
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(RateOut.fromJson)
          .toList();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid rates response format.',
    );
  }

  Future<RateOut> createRate(String employeeId, RateCreateRequest body) async {
    final response = await _dio.post(
      '/v1/payroll/rates/$employeeId',
      data: body.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return RateOut.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid create rate response format.',
    );
  }

  Future<RateOut> updateRate(String rateId, Map<String, dynamic> body) async {
    final response = await _dio.patch(
      '/v1/payroll/rates/$rateId',
      data: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return RateOut.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid update rate response format.',
    );
  }

  Future<List<PeriodOut>> getPeriods({String? branchId}) async {
    final response = await _dio.get(
      '/v1/payroll/periods',
      queryParameters: {
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
      },
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(PeriodOut.fromJson)
          .toList();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid periods response format.',
    );
  }

  Future<PeriodOut> createPeriod(PeriodCreateRequest body) async {
    final response = await _dio.post('/v1/payroll/periods', data: body.toJson());
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return PeriodOut.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid create period response format.',
    );
  }

  Future<PeriodOut> calculatePeriod(String periodId) async {
    final response = await _dio.post('/v1/payroll/periods/$periodId/calculate');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return PeriodOut.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid calculate period response format.',
    );
  }

  Future<PeriodOut> closePeriod(String periodId) async {
    final response = await _dio.post('/v1/payroll/periods/$periodId/close');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return PeriodOut.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid close period response format.',
    );
  }

  Future<List<ResultOut>> getPeriodResults(String periodId) async {
    final response = await _dio.get('/v1/payroll/periods/$periodId/results');
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ResultOut.fromJson)
          .toList();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid period results response format.',
    );
  }

  Future<EmployeeBalanceOut> getEmployeeBalance(String employeeId) async {
    final response = await _dio.get('/v1/payroll/employees/$employeeId/balance');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return EmployeeBalanceOut.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid employee balance response format.',
    );
  }

  Future<Uint8List> exportPeriodCsv(String periodId) async {
    final response = await _dio.get<List<int>>(
      '/v1/payroll/periods/$periodId/export.csv',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data != null) {
      return Uint8List.fromList(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid CSV export response format.',
    );
  }

  Future<Map<String, dynamic>> getSummaryReport({
    String? periodId,
    DateTime? fromDate,
    DateTime? toDate,
    String? branchId,
  }) async {
    final queryParameters = <String, dynamic>{
      if (periodId != null && periodId.isNotEmpty) 'period_id': periodId,
      if (fromDate != null) 'from_date': fmtPayrollDate(fromDate),
      if (toDate != null) 'to_date': fmtPayrollDate(toDate),
      if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
    };
    final response = await _dio.get(
      '/v1/payroll/reports/summary',
      queryParameters: queryParameters,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid summary report response format.',
    );
  }

  Future<List<EmployeeModel>> getEmployees({String? branchId}) async {
    final response = await _dio.get(
      '/v1/employees/clocked-in-status',
      queryParameters: {
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
      },
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(EmployeeModel.fromJson)
          .toList();
    }
    return [];
  }
}
