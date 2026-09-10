import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/models/shift_participant_models.dart';
import 'package:rostiq/features/shifts/widgets/shift_participants_section.dart';

void main() {
  testWidgets('shows host caption and one active participant row', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 10);
    final participant = ShiftParticipantOut(
      id: 'shift-participant-1',
      shiftId: 'shift-1',
      participantId: 'client-a',
      allocationStrategy: 'percentage',
      allocationValue: 60,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    final shift = ShiftOut(
      id: 'shift-1',
      tenantId: 'tenant-1',
      jobId: 'job-1',
      jobTitle: 'Community outing',
      clientId: 'client-a',
      clientName: 'Alice',
      scheduledStart: now,
      scheduledEnd: now.add(const Duration(hours: 2)),
      requiredSlots: 1,
      openSlots: 1,
      status: 'draft',
      participants: [participant],
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftParticipantsSection(
            shift: shift,
            clients: const [(id: 'client-a', name: 'Alice')],
            participantNames: const {'client-a': 'Alice'},
            canManage: true,
            isSaving: false,
            onAdd: (_) async {},
            onUpdate: (_, __) async {},
            onReplaceTimeBased: (_, __) async {},
            onRemove: (_, __) async {},
          ),
        ),
      ),
    );

    expect(find.text('Participants'), findsOneWidget);
    expect(find.text('Host job client: Alice'), findsOneWidget);
    expect(find.text('Alice (host)'), findsOneWidget);
    expect(find.text('Percentage · 60%'), findsOneWidget);
    expect(find.text('Sum: 60% · Remaining: 40%'), findsOneWidget);
  });
}
