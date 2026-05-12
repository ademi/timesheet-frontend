import 'package:dio/dio.dart';

import '../../models/attendance/employee_model.dart';
import '../../models/payment/create_payment_request.dart';
import '../../models/payment/payment_out.dart';
import '../../models/payment/payment_report_row.dart';

class PaymentRemoteDataSource {
  PaymentRemoteDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<PaymentOut> createPayment(CreatePaymentRequest request) async {
    final response = await _dio.post('/v1/payments', data: request.toJson());
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return PaymentOut.fromJson(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid create payment response format.',
    );
  }

  Future<List<PaymentReportRow>> getPaymentsReport({
    required String from,
    required String to,
    String? employeeId,
    String? branchId,
  }) async {
    final queryParameters = <String, dynamic>{
      'from': from,
      'to': to,
      if (employeeId != null && employeeId.isNotEmpty) 'employee_id': employeeId,
      if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
    };
    final response = await _dio.get(
      '/v1/payments/report',
      queryParameters: queryParameters,
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(PaymentReportRow.fromJson)
          .toList();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid payments report response format.',
    );
  }

  Future<List<PaymentOut>> getEmployeePaymentHistory(String employeeId) async {
    final response = await _dio.get('/v1/payments/employees/$employeeId');
    final data = response.data;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(PaymentOut.fromJson).toList();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Invalid payment history response format.',
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
      return data.whereType<Map<String, dynamic>>().map(EmployeeModel.fromJson).toList();
    }
    return [];
  }
}
