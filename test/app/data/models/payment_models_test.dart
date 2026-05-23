import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/create_payment_request.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/payment_out.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/payment_report_row.dart';

void main() {
  group('Payment JSON parsing', () {
    test('CreatePaymentRequest toJson/fromJson matches backend contract', () {
      const request = CreatePaymentRequest(
        employeeId: 'emp-1',
        periodId: 'period-1',
        paymentDate: '2026-05-09',
        amountPaid: 1250.0,
        currencyCode: 'USD',
        paymentMethod: 'bank_transfer',
        referenceNo: 'TRX-001',
        payrollResultId: 'payroll-1',
        notes: 'monthly salary',
      );

      final json = request.toJson();
      expect(json['employee_id'], 'emp-1');
      expect(json['period_id'], 'period-1');
      expect(json['payment_date'], '2026-05-09');
      expect(json['amount_paid'], 1250.0);
      expect(json['currency_code'], 'USD');
      expect(json['payment_method'], 'bank_transfer');

      final parsed = CreatePaymentRequest.fromJson(json);
      expect(parsed.employeeId, request.employeeId);
      expect(parsed.referenceNo, request.referenceNo);
    });

    test('PaymentOut fromJson/toJson supports nullable fields', () {
      final map = <String, dynamic>{
        'id': 'p-1',
        'tenant_id': 't-1',
        'employee_id': 'e-1',
        'period_id': 'period-1',
        'payroll_result_id': null,
        'payment_date': '2026-05-09',
        'amount_paid': 500.5,
        'currency_code': 'USD',
        'payment_method': null,
        'reference_no': null,
        'notes': null,
        'created_by_user_id': null,
        'created_at': '2026-05-09T11:10:00Z',
        'updated_at': '2026-05-09T11:10:00Z',
      };

      final model = PaymentOut.fromJson(map);
      expect(model.id, 'p-1');
      expect(model.amountPaid, 500.5);
      expect(model.paymentMethod, isNull);

      final encoded = model.toJson();
      expect(encoded['payment_date'], '2026-05-09');
      expect(encoded['currency_code'], 'USD');
    });

    test('PaymentReportRow fromJson/toJson parses report row', () {
      final map = <String, dynamic>{
        'payment_id': 'p-2',
        'payment_date': '2026-05-08',
        'amount_paid': 750.25,
        'currency_code': 'AUD',
        'payment_method': 'cash',
        'reference_no': 'REF-11',
        'created_at': '2026-05-08T08:00:00Z',
        'employee_id': 'e-2',
        'employee_code': 'EMP-002',
        'employee_name': 'John Doe',
        'branch_id': 'b-1',
      };

      final row = PaymentReportRow.fromJson(map);
      expect(row.employeeName, 'John Doe');
      expect(row.amountPaid, 750.25);
      expect(row.paymentMethod, 'cash');

      final encoded = row.toJson();
      expect(encoded['employee_code'], 'EMP-002');
      expect(encoded['branch_id'], 'b-1');
    });
  });
}
