import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/widgets/keyboard_time_field.dart';

void main() {
  group('parseHhMm', () {
    test('accepts 9:30 and 0930', () {
      expect(parseHhMm('9:30'), const TimeOfDay(hour: 9, minute: 30));
      expect(parseHhMm('0930'), const TimeOfDay(hour: 9, minute: 30));
      expect(parseHhMm('25:00'), isNull);
    });

    test('accepts zero-padded HH:mm', () {
      expect(parseHhMm('09:30'), const TimeOfDay(hour: 9, minute: 30));
      expect(parseHhMm('23:59'), const TimeOfDay(hour: 23, minute: 59));
    });

    test('rejects invalid compact and minute values', () {
      expect(parseHhMm('936'), isNull);
      expect(parseHhMm('12:60'), isNull);
      expect(parseHhMm(''), isNull);
    });
  });

  testWidgets('KeyboardTimeField commits on submit', (tester) async {
    TimeOfDay? committed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardTimeField(
            label: 'Start time',
            value: const TimeOfDay(hour: 9, minute: 0),
            onChanged: (time) => committed = time,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '14:30');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(committed, const TimeOfDay(hour: 14, minute: 30));
  });

  testWidgets('KeyboardTimeField commits on blur', (tester) async {
    TimeOfDay? committed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              KeyboardTimeField(
                label: 'Start time',
                value: const TimeOfDay(hour: 9, minute: 0),
                onChanged: (time) => committed = time,
              ),
              const TextField(key: Key('other')),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '0930');
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();

    expect(committed, const TimeOfDay(hour: 9, minute: 30));
  });

  testWidgets('KeyboardTimeField shows error for invalid input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              KeyboardTimeField(
                label: 'Start time',
                value: const TimeOfDay(hour: 9, minute: 0),
                onChanged: (_) {},
              ),
              const TextField(key: Key('other')),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '25:00');
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();

    expect(find.text('Enter time as HH:mm'), findsOneWidget);
  });
}
