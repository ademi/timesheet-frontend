import '../payroll/payroll_date_utils.dart';

class EmployeeUpdateRequest {
  const EmployeeUpdateRequest({
    this.fullName,
    this.phone,
    this.email,
    this.dob,
    this.isActive,
    this.defaultCurrencyCode,
    this.roleId,
  });

  final String? fullName;
  final String? phone;
  final String? email;
  final DateTime? dob;
  final bool? isActive;
  final String? defaultCurrencyCode;
  final String? roleId;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (fullName != null) json['full_name'] = fullName;
    if (phone != null) json['phone'] = phone;
    if (email != null) json['email'] = email;
    if (dob != null) json['dob'] = fmtPayrollDate(dob!);
    if (isActive != null) json['is_active'] = isActive;
    if (defaultCurrencyCode != null) {
      json['default_currency_code'] = defaultCurrencyCode;
    }
    if (roleId != null) {
      json['role_id'] = roleId;
    }
    return json;
  }
}
