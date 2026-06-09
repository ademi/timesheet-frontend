import 'dart:typed_data';

import '../../../core/services/token_storage.dart';
import '../datasources/remote/payroll_remote_datasource.dart';
import '../models/attendance/employee_model.dart';
import '../models/payroll/employee_balance_out.dart';
import '../models/payroll/payroll_summary_row.dart';
import '../models/payroll/period_create_request.dart';
import '../models/payroll/period_out.dart';
import '../models/payroll/rate_create_request.dart';
import '../models/payroll/rate_out.dart';
import '../models/payroll/result_out.dart';

class PayrollRepository {
  PayrollRepository({
    required PayrollRemoteDataSource remote,
    required TokenStorage tokenStorage,
  })  : _remote = remote,
        _tokenStorage = tokenStorage;

  final PayrollRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  Future<List<RateOut>> getRates(String employeeId) =>
      _remote.getRates(employeeId);

  Future<RateOut> createRate(String employeeId, RateCreateRequest body) =>
      _remote.createRate(employeeId, body);

  Future<RateOut> updateRate(String rateId, Map<String, dynamic> body) =>
      _remote.updateRate(rateId, body);

  Future<List<PeriodOut>> getPeriods() =>
      _remote.getPeriods(branchId: _tokenStorage.branchId);

  Future<PeriodOut> createPeriod(PeriodCreateRequest body) => _remote.createPeriod(
        PeriodCreateRequest(
          periodStart: body.periodStart,
          periodEnd: body.periodEnd,
          branchId: _tokenStorage.branchId,
        ),
      );

  Future<PeriodOut> calculatePeriod(String periodId) =>
      _remote.calculatePeriod(periodId);

  Future<PeriodOut> closePeriod(String periodId) => _remote.closePeriod(periodId);

  Future<List<ResultOut>> getPeriodResults(String periodId) =>
      _remote.getPeriodResults(periodId);

  Future<EmployeeBalanceOut> getEmployeeBalance(String employeeId) =>
      _remote.getEmployeeBalance(employeeId);

  Future<Uint8List> exportPeriodCsv(String periodId) =>
      _remote.exportPeriodCsv(periodId);

  Future<Map<String, dynamic>> getSummaryReport({
    String? periodId,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _remote.getSummaryReport(
        periodId: periodId,
        fromDate: fromDate,
        toDate: toDate,
        branchId: _tokenStorage.branchId,
      );

  Future<List<EmployeeModel>> getEmployees() =>
      _remote.getEmployees(branchId: _tokenStorage.branchId);

  List<PayrollSummaryRow> parseSummaryRows(Map<String, dynamic> response) {
    final rows = response['rows'];
    if (rows is! List) return [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(PayrollSummaryRow.fromJson)
        .toList();
  }
}
