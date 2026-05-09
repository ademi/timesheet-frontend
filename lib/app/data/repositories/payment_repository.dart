import '../datasources/remote/payment_remote_datasource.dart';
import '../models/attendance/employee_model.dart';
import '../models/payment/create_payment_request.dart';
import '../models/payment/payment_out.dart';
import '../models/payment/payment_report_row.dart';

class PaymentRepository {
  PaymentRepository({required PaymentRemoteDataSource remote}) : _remote = remote;

  final PaymentRemoteDataSource _remote;

  Future<PaymentOut> createPayment(CreatePaymentRequest request) {
    return _remote.createPayment(request);
  }

  Future<List<PaymentReportRow>> getPaymentsReport({
    required String from,
    required String to,
    String? employeeId,
    String? branchId,
  }) {
    return _remote.getPaymentsReport(
      from: from,
      to: to,
      employeeId: employeeId,
      branchId: branchId,
    );
  }

  Future<List<PaymentOut>> getEmployeePaymentHistory(String employeeId) {
    return _remote.getEmployeePaymentHistory(employeeId);
  }

  Future<List<EmployeeModel>> getEmployees({String? branchId}) {
    return _remote.getEmployees(branchId: branchId);
  }
}
