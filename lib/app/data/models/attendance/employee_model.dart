class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.userId,
    required this.employeeCode,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.dob,
    required this.isActive,
    required this.clockedIn,
  });

  final String id;
  final String tenantId;
  final String branchId;
  final String userId;
  final String employeeCode;
  final String fullName;
  final String phone;
  final String email;
  final String dob;
  final bool isActive;
  final bool clockedIn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'user_id': userId,
    'employee_code': employeeCode,
    'full_name': fullName,
    'phone': phone,
    'email': email,
    'dob': dob,
    'is_active': isActive,
    'clockedin': clockedIn,
  };

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      userId: json['user_id'] as String,
      employeeCode: json['employee_code'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      dob: json['dob'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      clockedIn: json['clockedin'] as bool? ?? false,
    );
  }
}
