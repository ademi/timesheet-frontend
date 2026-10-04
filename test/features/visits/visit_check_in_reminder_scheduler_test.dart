import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/visits/services/visit_check_in_reminder_scheduler.dart';

void main() {
  final now = DateTime.utc(2026, 9, 23, 8);

  test('plans reminder at scheduledStart - leadTime for scheduled visits', () {
    final plans = planCheckInReminders(
      now: now,
      visits: [
        VisitReminderInput(
          visitId: 'v1',
          scheduledStart: now.add(const Duration(minutes: 30)),
          status: 'scheduled',
        ),
        VisitReminderInput(
          visitId: 'v2',
          scheduledStart: now.add(const Duration(hours: 2)),
          status: 'scheduled',
        ),
      ],
    );
    expect(plans, hasLength(2));
    expect(plans.first.visitId, 'v1');
    expect(
      plans.first.fireAt,
      now.add(const Duration(minutes: 15)),
    );
  });

  test('skips checked-in and past fire windows', () {
    final plans = planCheckInReminders(
      now: now,
      visits: [
        VisitReminderInput(
          visitId: 'done',
          scheduledStart: now.add(const Duration(minutes: 30)),
          status: 'checked_in',
        ),
        VisitReminderInput(
          visitId: 'soon',
          scheduledStart: now.add(const Duration(minutes: 10)),
          status: 'scheduled',
        ),
      ],
    );
    expect(plans, isEmpty);
  });
}
