import '../../../core/services/token_storage.dart';
import '../datasources/remote/payment_remote_datasource.dart';
import '../models/attendance/employee_model.dart';
import '../models/payment/create_payment_request.dart';
import '../models/payment/payment_out.dart';
import '../models/payment/payment_report_row.dart';

class PaymentRepository {
  PaymentRepository({
    required PaymentRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  final PaymentRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  Future<PaymentOut> createPayment(CreatePaymentRequest request) {
    return _remote.createPayment(request);
  }

  Future<List<PaymentReportRow>> getPaymentsReport({
    required String from,
    required String to,
    String? employeeId,
    String? periodId,
  }) {
    return _remote.getPaymentsReport(
      from: from,
      to: to,
      employeeId: employeeId,
      branchId: _tokenStorage.branchId,
      periodId: periodId,
    );
  }

  Future<List<PaymentOut>> getEmployeePaymentHistory(String employeeId) {
    return _remote.getEmployeePaymentHistory(employeeId);
  }

  Future<List<EmployeeModel>> getEmployees() {
    return _remote.getEmployees(branchId: _tokenStorage.branchId);
  }
}
