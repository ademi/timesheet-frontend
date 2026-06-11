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
