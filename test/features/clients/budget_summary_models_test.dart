import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/budget_summary_models.dart';

void main() {
  test('parses and orders all four budget envelopes', () {
    final summary = BudgetSummaryOut.fromJson({
      'client_id': 'client-1',
      'envelopes': [
        {'key': 'capital', 'declared': null, 'spent': 20, 'remaining': null},
        {'key': 'core', 'declared': 100, 'spent': 125.5, 'remaining': -25.5},
      ],
    });

    expect(summary.clientId, 'client-1');
    expect(summary.envelopes.map((e) => e.key), budgetEnvelopeKeys);
    expect(summary.envelopes.first.declared, 100);
    expect(summary.envelopes.first.spent, 125.5);
    expect(summary.envelopes.first.remaining, -25.5);
    expect(summary.envelopes[1].spent, 0);
    expect(summary.envelopes[2].declared, isNull);
  });
}
