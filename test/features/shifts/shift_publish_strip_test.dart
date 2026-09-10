import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/models/shift_participant_models.dart';
import 'package:rostiq/features/shifts/widgets/shift_publish_strip.dart';

void main() {
  testWidgets('draft with 60 percent disables publish and explains why', (
    tester,
  ) async {
    final shift = _shift(participants: [_participant(value: 60)]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftPublishStrip(
            shift: shift,
            canManage: true,
            canPublish: false,
            isSaving: false,
            showDraftCapacityHint: false,
            onPublish: () async {},
            onDismissHint: () {},
          ),
        ),
      ),
    );

    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
    expect(
      find.text('Active percentages must total 100% (now 60%).'),
      findsOneWidget,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('post-create capacity hint appears and is dismissible', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftPublishStrip(
            shift: _shift(participants: [_participant(value: 60)]),
            canManage: true,
            canPublish: false,
            isSaving: false,
            showDraftCapacityHint: true,
            onPublish: () async {},
            onDismissHint: () => dismissed = true,
          ),
        ),
      ),
    );

    expect(
      find.text('Draft saved. Adjust capacity to 100% to publish.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Dismiss'));
    expect(dismissed, isTrue);
  });
}

ShiftOut _shift({required List<ShiftParticipantOut> participants}) {
  final now = DateTime.utc(2026, 9, 10);
  return ShiftOut(
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
    participants: participants,
    createdAt: now,
    updatedAt: now,
  );
}

ShiftParticipantOut _participant({required double value}) {
  final now = DateTime.utc(2026, 9, 10);
  return ShiftParticipantOut(
    id: 'shift-participant-1',
    shiftId: 'shift-1',
    participantId: 'client-a',
    allocationStrategy: 'percentage',
    allocationValue: value,
    status: 'active',
    createdAt: now,
    updatedAt: now,
  );
}
