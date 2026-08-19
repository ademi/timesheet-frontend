import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/widgets/visit_day_agenda.dart';

void main() {
  testWidgets('groups visits onto separate local day headers', (tester) async {
    var opened = '';
    final first = DateTime(2026, 8, 18, 9);
    final second = DateTime(2026, 8, 19, 10);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisitDayAgenda(
            visits: [
              AgendaVisit(
                start: first,
                end: first.add(const Duration(hours: 1)),
                title: 'Morning support',
                status: 'scheduled',
                onOpen: () => opened = 'first',
              ),
              AgendaVisit(
                start: second,
                end: second.add(const Duration(hours: 1)),
                title: 'Evening support',
                status: 'completed',
                onOpen: () => opened = 'second',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Tue 18/8'), findsOneWidget);
    expect(find.text('Wed 19/8'), findsOneWidget);
    expect(find.text('Morning support'), findsOneWidget);
    expect(find.text('Evening support'), findsOneWidget);

    await tester.tap(find.text('Morning support'));
    await tester.pump();
    expect(opened, 'first');
  });
}
