class PaymentReportRow {
  const PaymentReportRow({
    required this.paymentId,
    required this.paymentDate,
    required this.amountPaid,
    required this.currencyCode,
    this.paymentMethod,
    this.referenceNo,
    required this.createdAt,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    this.branchId,
    this.periodId,
    this.periodStart,
    this.periodEnd,
  });

  final String paymentId;
  final String paymentDate;
  final double amountPaid;
  final String currencyCode;
  final String? paymentMethod;
  final String? referenceNo;
  final String createdAt;
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final String? branchId;
  final String? periodId;
  final String? periodStart;
  final String? periodEnd;

  Map<String, dynamic> toJson() => {
    'payment_id': paymentId,
    'payment_date': paymentDate,
    'amount_paid': amountPaid,
    'currency_code': currencyCode,
    'payment_method': paymentMethod,
    'reference_no': referenceNo,
    'created_at': createdAt,
    'employee_id': employeeId,
    'employee_code': employeeCode,
    'employee_name': employeeName,
    'branch_id': branchId,
    'period_id': periodId,
    'period_start': periodStart,
    'period_end': periodEnd,
  };

  factory PaymentReportRow.fromJson(Map<String, dynamic> json) {
    return PaymentReportRow(
      paymentId: json['payment_id'] as String? ?? '',
      paymentDate: json['payment_date'] as String? ?? '',
      amountPaid: _asDouble(json['amount_paid']),
      currencyCode: json['currency_code'] as String? ?? 'USD',
      paymentMethod: json['payment_method'] as String?,
      referenceNo: json['reference_no'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      branchId: json['branch_id'] as String?,
      periodId: json['period_id'] as String?,
      periodStart: json['period_start'] as String?,
      periodEnd: json['period_end'] as String?,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
