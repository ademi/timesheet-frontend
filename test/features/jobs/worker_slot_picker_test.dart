import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/widgets/worker_slot_picker.dart';

void main() {
  testWidgets('rejects duplicate worker and keeps prior slot', (tester) async {
    final slots = <String?>[null, null];
    final engagements = const [
      WorkerSlotEngagement(contractorId: 'c1', displayName: 'Alex'),
      WorkerSlotEngagement(contractorId: 'c2', displayName: 'Blair'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return WorkerSlotPicker(
                slots: List<String?>.from(slots),
                engagements: engagements,
                onChanged: (index, contractorId) {
                  if (contractorId != null) {
                    for (var i = 0; i < slots.length; i++) {
                      if (i != index && slots[i] == contractorId) {
                        setState(() {});
                        return false;
                      }
                    }
                  }
                  setState(() => slots[index] = contractorId);
                  return true;
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('assign-slot-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex').last);
    await tester.pumpAndSettle();
    expect(slots, ['c1', null]);

    await tester.tap(find.byKey(const ValueKey('assign-slot-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex').last);
    await tester.pumpAndSettle();
    expect(slots, ['c1', null]);
  });

  testWidgets('Unfilled clears selected contractor id', (tester) async {
    final slots = <String?>['c1'];
    final engagements = const [
      WorkerSlotEngagement(contractorId: 'c1', displayName: 'Alex'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return WorkerSlotPicker(
                slots: List<String?>.from(slots),
                engagements: engagements,
                onChanged: (index, contractorId) {
                  setState(() => slots[index] = contractorId);
                  return true;
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Alex'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assign-slot-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unfilled').last);
    await tester.pumpAndSettle();
    expect(slots, [null]);
  });
}
