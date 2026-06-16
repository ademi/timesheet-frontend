import '../data/models/attendance/attendance_adjustment_request.dart';
import '../data/models/attendance/attendance_exception_model.dart';
import '../data/models/attendance/employee_model.dart';
import '../data/models/payroll/rate_out.dart';
import '../data/models/payroll/result_out.dart';

class EmployeeRateFormArgs {
  const EmployeeRateFormArgs({
    required this.employeeId,
    this.rate,
    this.finishCreateFlowOnSave = false,
  });

  final String employeeId;
  final RateOut? rate;

  /// When true, saving a new rate also closes the create-employee screen so the
  /// user returns to the employees list instead of the empty create form.
  final bool finishCreateFlowOnSave;

  bool get isEdit => rate != null;
}

class EmployeePickerArgs {
  const EmployeePickerArgs({this.title});

  final String? title;
}

class EmployeeCreatedArgs {
  const EmployeeCreatedArgs({required this.employeeId});

  final String employeeId;
}

class PayrollResultDetailArgs {
  const PayrollResultDetailArgs({required this.result});

  final ResultOut result;
}

/// Returned from [EmployeePickerView] via `Get.back`.
class EmployeePickerResult {
  const EmployeePickerResult(this.employee);

  final EmployeeModel employee;
}

/// Arguments for the admin attendance adjustment form.
class AttendanceAdjustmentArgs {
  const AttendanceAdjustmentArgs({
    required this.action,
    required this.employeeId,
    required this.employeeName,
    this.timeEntryId,
    this.initialClockInAt,
    this.initialClockOutAt,
    this.exceptionType,
  });

  /// Builds args for an exception-queue row, choosing the right default action.
  factory AttendanceAdjustmentArgs.forException(
    AttendanceExceptionModel exception, {
    required String employeeName,
  }) {
    final AdjustmentAction action;
    if (!exception.hasOpenEntry) {
      action = AdjustmentAction.adminCreateManualEntry;
    } else if (exception.exceptionType == 'missing_clock_out') {
      action = AdjustmentAction.adminAddClockOut;
    } else {
      action = AdjustmentAction.adminEditEntry;
    }
    return AttendanceAdjustmentArgs(
      action: action,
      employeeId: exception.employeeId,
      employeeName: employeeName,
      timeEntryId: exception.hasOpenEntry ? exception.id : null,
      initialClockInAt: exception.clockInAt,
      initialClockOutAt: exception.clockOutAt,
      exceptionType: exception.exceptionType,
    );
  }

  /// Builds args for a fresh manual entry from an employee chosen by the admin.
  factory AttendanceAdjustmentArgs.manualEntry({
    required String employeeId,
    required String employeeName,
  }) {
    return AttendanceAdjustmentArgs(
      action: AdjustmentAction.adminCreateManualEntry,
      employeeId: employeeId,
      employeeName: employeeName,
    );
  }

  final AdjustmentAction action;
  final String employeeId;
  final String employeeName;
  final String? timeEntryId;
  final DateTime? initialClockInAt;
  final DateTime? initialClockOutAt;
  final String? exceptionType;
}
