import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/support_plan_models.dart';
import 'package:rostiq/features/visits/widgets/shift_brief_panel.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets('valid brief shows alerts, goals, access; no budget labels',
      (tester) async {
    const brief = ShiftBriefDto(
      clientId: 'c1',
      clientName: 'Ada',
      planBodyInvalid: false,
      allergies: 'Peanuts',
      accessNotes: 'Gate code 1234',
      medicationSchedule: '8am meds',
      behaviourSupportPlan: true,
      communicationMethods: ['Auslan'],
      routines: 'Breakfast 8am',
      goals: [
        {
          'ndis_goal': 'Cook independently',
          'worker_instructions': 'Use visual card',
        },
      ],
      triggers: 'Loud noise',
    );

    await tester.pumpWidget(_wrap(const ShiftBriefPanel(brief: brief)));

    expect(find.text('Shift brief'), findsOneWidget);
    expect(find.textContaining('Allergies: Peanuts'), findsOneWidget);
    expect(find.textContaining('Medication: 8am meds'), findsOneWidget);
    expect(find.textContaining('Behaviour support plan'), findsOneWidget);
    expect(find.text('Use visual card'), findsOneWidget);
    expect(find.text('Gate code 1234'), findsOneWidget);
    expect(find.text('Breakfast 8am'), findsOneWidget);
    expect(find.textContaining('Core budget'), findsNothing);
    expect(find.textContaining('budget_core'), findsNothing);
  });

  testWidgets(
      'planBodyInvalid shows unavailable + allergies/access; hides care body',
      (tester) async {
    const brief = ShiftBriefDto(
      clientId: 'c1',
      clientName: 'Ada',
      planBodyInvalid: true,
      allergies: 'Peanuts',
      accessNotes: 'Gate code 1234',
      // Care fields must not render when invalid even if present locally
      routines: 'Breakfast 8am',
      medicationSchedule: '8am meds',
      goals: [
        {'worker_instructions': 'Use visual card'},
      ],
    );

    await tester.pumpWidget(_wrap(const ShiftBriefPanel(brief: brief)));

    expect(
      find.text('Support plan unavailable — contact coordinator'),
      findsOneWidget,
    );
    expect(find.textContaining('Allergies: Peanuts'), findsOneWidget);
    expect(find.text('Gate code 1234'), findsOneWidget);
    expect(find.text('Breakfast 8am'), findsNothing);
    expect(find.text('Use visual card'), findsNothing);
    expect(find.textContaining('Medication:'), findsNothing);
  });
}
