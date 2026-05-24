import '../datasources/remote/employee_remote_datasource.dart';
import '../models/attendance/employee_model.dart';
import '../models/attendance/employee_role_option.dart';
import '../models/attendance/employee_update_request.dart';
import '../models/attendance/time_entry_out.dart';

class EmployeeRepository {
  EmployeeRepository({required EmployeeRemoteDataSource remote}) : _remote = remote;

  final EmployeeRemoteDataSource _remote;

  Future<List<EmployeeModel>> listEmployees() => _remote.listEmployees();

  Future<EmployeeModel> getEmployee(String employeeId) =>
      _remote.getEmployee(employeeId);

  Future<EmployeeModel> updateEmployee(
    String employeeId,
    EmployeeUpdateRequest body,
  ) =>
      _remote.updateEmployee(employeeId, body);

  Future<List<EmployeeRoleOption>> listRoleOptions() =>
      _remote.listRoleOptions();

  Future<List<TimeEntryOut>> listTimeEntries({
    required String employeeId,
    required DateTime from,
    required DateTime to,
  }) =>
      _remote.listTimeEntries(employeeId: employeeId, from: from, to: to);
}
