import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_participant_models.dart';
import 'package:rostiq/features/shifts/widgets/participant_allocation_form.dart';

void main() {
  final shiftStart = DateTime(2026, 9, 10, 9);
  final shiftEnd = DateTime(2026, 9, 10, 12);

  testWidgets('entering 60% and reason yields create request', (tester) async {
    ShiftParticipantCreateRequest? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ParticipantAllocationForm(
              clients: const [
                (id: 'client-a', name: 'Alice'),
                (id: 'client-b', name: 'Bob'),
              ],
              excludeClientIds: const {'client-b'},
              shiftStart: shiftStart,
              shiftEnd: shiftEnd,
              remainingPercentage: 100,
              onSubmit: (request) {
                captured = request;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Remaining: 100%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('participant-allocation-form-client')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('participant-allocation-form-percentage')),
      '60',
    );
    await tester.pump();

    expect(find.text('Remaining: 40%'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('participant-allocation-form-reason')),
      'Split with co-client',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('participant-allocation-form-submit')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.participantId, 'client-a');
    expect(captured!.allocationStrategy, 'percentage');
    expect(captured!.allocationValue, 60);
    expect(captured!.reason, 'Split with co-client');
    expect(captured!.timeWindows, isNull);
  });

  testWidgets('shows remaining label from prop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParticipantAllocationForm(
            clients: const [(id: 'client-a', name: 'Alice')],
            excludeClientIds: const {},
            shiftStart: shiftStart,
            shiftEnd: shiftEnd,
            remainingPercentage: 35,
            onSubmit: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Remaining: 35%'), findsOneWidget);
  });

  testWidgets('edit mode rejects percentage above remaining budget', (
    tester,
  ) async {
    ShiftParticipantAllocationUpdateRequest? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ParticipantAllocationForm(
              clients: const [(id: 'client-a', name: 'Alice')],
              excludeClientIds: const {},
              shiftStart: shiftStart,
              shiftEnd: shiftEnd,
              lockStrategy: 'percentage',
              remainingPercentage: 40,
              submitLabel: 'Save',
              initialParticipantId: 'client-a',
              initialAllocationValue: 40,
              onSubmit: (_) {},
              onSubmitUpdate: (request) {
                captured = request;
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('participant-allocation-form-percentage')),
      '70',
    );
    await tester.enterText(
      find.byKey(const Key('participant-allocation-form-reason')),
      'Raise share',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('participant-allocation-form-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Exceeds remaining'), findsOneWidget);
    expect(captured, isNull);
  });
}
