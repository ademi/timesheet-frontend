import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/roster/roster_grid_model.dart';
import 'package:rostiq/features/visits/roster/roster_grid_view.dart';

void main() {
  testWidgets('shows Unfilled row and day headers', (tester) async {
    final monday = DateTime(2026, 8, 10);
    final grid = buildRosterGrid(
      rangeStart: monday,
      dayCount: 5,
      shifts: const [],
      people: const [RosterPerson(contractorId: 'jane', displayName: 'Jane')],
      overlay: const RosterOverlayOut(contractors: []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RosterGridView(
            grid: grid,
            onTileTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Unfilled'), findsOneWidget);
    expect(find.textContaining('Mon'), findsWidgets);
    expect(find.text('Jane'), findsOneWidget);
  });

  testWidgets('shows visit status chip Live for scheduled', (tester) async {
    final monday = DateTime(2026, 8, 10, 9);
    final shift = ShiftOut(
      id: 's1',
      tenantId: 't',
      jobId: 'j',
      jobTitle: 'Support',
      clientId: 'cl',
      clientName: 'Sam',
      scheduledStart: monday,
      scheduledEnd: monday.add(const Duration(hours: 2)),
      requiredSlots: 1,
      openSlots: 0,
      status: 'published',
      assignments: const [
        ShiftAssignmentOut(
          id: 'a1',
          contractorId: 'jane',
          contractorName: 'Jane',
          visitId: 'v1',
          source: 'staff_assign',
          status: 'active',
          visitStatus: 'scheduled',
        ),
      ],
      createdAt: monday,
      updatedAt: monday,
    );
    final grid = buildRosterGrid(
      rangeStart: DateTime(2026, 8, 10),
      dayCount: 5,
      shifts: [shift],
      people: const [RosterPerson(contractorId: 'jane', displayName: 'Jane')],
      overlay: const RosterOverlayOut(contractors: []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RosterGridView(grid: grid, onTileTap: (_) {}),
        ),
      ),
    );
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
  });
}
