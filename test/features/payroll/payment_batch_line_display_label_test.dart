import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/payroll/data/models/payroll_models.dart';

void main() {
  test('displayLabel shows contractor name only', () {
    const line = PaymentBatchLineOut(
      visitId: 'c3000001-0001-4001-8001-000000000014',
      contractorId: 'contractor-1',
      hours: 3,
      rate: 44,
      amount: 132,
      contractorName: 'Jane Rivera',
      clientName: 'Amelia',
      locationLabel: 'Home',
    );

    expect(line.displayLabel, 'Jane Rivera');
  });

  test('displayLabel falls back to short visit id when name missing', () {
    const idsOnly = PaymentBatchLineOut(
      visitId: 'c3000001-0001-4001-8001-000000000014',
      contractorId: 'contractor-1',
      hours: 1,
      rate: 10,
      amount: 10,
    );
    expect(idsOnly.displayLabel, 'Visit c3000001…');
  });

  test('fromJson reads optional contractor_name', () {
    final line = PaymentBatchLineOut.fromJson({
      'visit_id': 'v1',
      'contractor_id': 'c1',
      'hours': 2,
      'rate': 40,
      'amount': 80,
      'contractor_name': 'Jane Rivera',
      'client_name': 'Finn',
      'location_label': 'Home',
    });

    expect(line.displayLabel, 'Jane Rivera');
  });
}
