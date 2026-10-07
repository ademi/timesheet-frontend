import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/widgets/app_time_picker.dart';

void main() {
  testWidgets('showAppTimePicker opens in inputOnly mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showAppTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 10, minute: 12),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // inputOnly shows hour/minute text fields; dial toggle is absent.
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byIcon(Icons.access_time), findsNothing);
    expect(find.byIcon(Icons.keyboard_outlined), findsNothing);
  });
}
