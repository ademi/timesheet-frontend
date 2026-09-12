import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/budget_summary_models.dart';
import 'package:rostiq/features/clients/widgets/client_budget_remaining_section.dart';

void main() {
  testWidgets('shows declared spent remaining and amber negative value', (
    tester,
  ) async {
    final summary = BudgetSummaryOut.fromJson({
      'client_id': 'client-1',
      'envelopes': [
        {'key': 'core', 'declared': 100, 'spent': 125, 'remaining': -25},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClientBudgetRemainingSection(summary: summary)),
      ),
    );

    expect(find.text('Budget remaining'), findsOneWidget);
    expect(find.text('\$100.00'), findsOneWidget);
    expect(find.text('\$125.00'), findsOneWidget);
    expect(find.text('-\$25.00'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(6));

    final negative = tester.widget<Text>(find.text('-\$25.00'));
    expect(negative.style?.color, const Color(0xFFB45309));
  });
}
