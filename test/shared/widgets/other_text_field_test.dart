import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/widgets/other_text_field.dart';

void main() {
  testWidgets('OtherTextField hidden when isOther is false', (tester) async {
    final ctrl = TextEditingController(text: 'hidden');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtherTextField(isOther: false, controller: ctrl),
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('OtherTextField shows labeled field when isOther is true',
      (tester) async {
    final ctrl = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtherTextField(
            isOther: true,
            controller: ctrl,
            label: 'Please specify',
          ),
        ),
      ),
    );

    expect(find.text('Please specify'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Godparent');
    expect(ctrl.text, 'Godparent');
  });
}
