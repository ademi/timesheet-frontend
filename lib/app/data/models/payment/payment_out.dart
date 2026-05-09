class PaymentOut {
  const PaymentOut({
    required this.id,
    required this.tenantId,
    required this.employeeId,
    this.payrollResultId,
    required this.paymentDate,
    required this.amountPaid,
    required this.currencyCode,
    this.paymentMethod,
    this.referenceNo,
    this.notes,
    this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String employeeId;
  final String? payrollResultId;
  final String paymentDate;
  final double amountPaid;
  final String currencyCode;
  final String? paymentMethod;
  final String? referenceNo;
  final String? notes;
  final String? createdByUserId;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'employee_id': employeeId,
    'payroll_result_id': payrollResultId,
    'payment_date': paymentDate,
    'amount_paid': amountPaid,
    'currency_code': currencyCode,
    'payment_method': paymentMethod,
    'reference_no': referenceNo,
    'notes': notes,
    'created_by_user_id': createdByUserId,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory PaymentOut.fromJson(Map<String, dynamic> json) {
    return PaymentOut(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      payrollResultId: json['payroll_result_id'] as String?,
      paymentDate: json['payment_date'] as String? ?? '',
      amountPaid: _asDouble(json['amount_paid']),
      currencyCode: json['currency_code'] as String? ?? 'USD',
      paymentMethod: json['payment_method'] as String?,
      referenceNo: json['reference_no'] as String?,
      notes: json['notes'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
