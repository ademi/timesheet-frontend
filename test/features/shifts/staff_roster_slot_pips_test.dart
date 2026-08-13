import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rostiq/features/shifts/widgets/shift_slot_pips.dart';

void main() {
  testWidgets('shows filled and open slot pips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShiftSlotPips(requiredSlots: 2, filledSlots: 1),
        ),
      ),
    );

    expect(find.byKey(const Key('slot-pip-filled')), findsOneWidget);
    expect(find.byKey(const Key('slot-pip-open')), findsOneWidget);
  });
}
