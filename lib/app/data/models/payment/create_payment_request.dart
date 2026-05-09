class CreatePaymentRequest {
  const CreatePaymentRequest({
    required this.employeeId,
    required this.paymentDate,
    required this.amountPaid,
    required this.currencyCode,
    this.paymentMethod,
    this.referenceNo,
    this.payrollResultId,
    this.notes,
  });

  final String employeeId;
  final String paymentDate;
  final double amountPaid;
  final String currencyCode;
  final String? paymentMethod;
  final String? referenceNo;
  final String? payrollResultId;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'payment_date': paymentDate,
    'amount_paid': amountPaid,
    'currency_code': currencyCode,
    'payment_method': paymentMethod,
    'reference_no': referenceNo,
    'payroll_result_id': payrollResultId,
    'notes': notes,
  };

  factory CreatePaymentRequest.fromJson(Map<String, dynamic> json) {
    return CreatePaymentRequest(
      employeeId: json['employee_id'] as String? ?? '',
      paymentDate: json['payment_date'] as String? ?? '',
      amountPaid: _asDouble(json['amount_paid']),
      currencyCode: json['currency_code'] as String? ?? 'USD',
      paymentMethod: json['payment_method'] as String?,
      referenceNo: json['reference_no'] as String?,
      payrollResultId: json['payroll_result_id'] as String?,
      notes: json['notes'] as String?,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
