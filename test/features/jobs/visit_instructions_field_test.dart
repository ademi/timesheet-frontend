import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/widgets/visit_instructions_field.dart';

void main() {
  testWidgets('shows textarea with instructions label', (tester) async {
    final controller = TextEditingController(text: 'Personal care\nTransport');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisitInstructionsField(controller: controller),
        ),
      ),
    );

    expect(find.text('Instructions for workers'), findsOneWidget);
    expect(find.byKey(const Key('visit-instructions-field')), findsOneWidget);
    expect(controller.text, 'Personal care\nTransport');
  });
}
