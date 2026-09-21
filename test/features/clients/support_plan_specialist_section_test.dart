import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rostiq/features/clients/models/support_plan_specialist_entry.dart';
import 'package:rostiq/features/clients/models/support_plan_specialist_types.dart';
import 'package:rostiq/features/clients/widgets/onboarding/support_plan_specialist_section.dart';
import 'package:rostiq/features/clients/widgets/onboarding/support_plan_specialists_panel.dart';

void main() {
  testWidgets('SupportPlanSpecialistSection shows all detail fields', (
    tester,
  ) async {
    final entry = SupportPlanSpecialistEntry.create(
      SupportPlanSpecialistTypes.supportCoordinator,
      expanded: true,
    );
    addTearDown(entry.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportPlanSpecialistSection(entry: entry, enabled: true),
        ),
      ),
    );

    expect(find.text('SC name'), findsOneWidget);
    expect(find.text('Company name'), findsOneWidget);
    expect(find.text('ACN/ABN'), findsOneWidget);
    expect(find.text('Organisation ID'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);
  });

  testWidgets('specialists panel picker has no coordinator type', (tester) async {
    final specialists = <SupportPlanSpecialistEntry>[].obs;
    addTearDown(() {
      for (final e in specialists) {
        e.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportPlanSpecialistsPanel(
            specialists: specialists,
            enabled: true,
            onAdd:
                (context) => SupportPlanSpecialistsPanel.showTypePicker(
                  context,
                  onSelected: (_) {},
                ),
            onRemove: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add support specialist'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Support coordinator'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Speech therapist'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Other specialist'), findsOneWidget);
  });
}
