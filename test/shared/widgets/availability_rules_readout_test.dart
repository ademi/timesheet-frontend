import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/shared/widgets/availability_rules_readout.dart';

void main() {
  testWidgets('empty rules show muted copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvailabilityRulesReadout(rules: []),
        ),
      ),
    );
    expect(find.text('No weekly availability set.'), findsOneWidget);
  });

  testWidgets('Monday window formats without seconds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvailabilityRulesReadout(
            rules: [
              AvailabilityRuleOut(
                dayOfWeek: 0,
                startTime: '09:00:00',
                endTime: '17:00:00',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('09:00–17:00'), findsOneWidget);
  });
}
