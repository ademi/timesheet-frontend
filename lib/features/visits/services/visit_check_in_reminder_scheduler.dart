/// Pure planner for pre-start check-in reminders (A19).
///
/// OS notification plugin is optional — this module only decides *when* and
/// *which* visits need a reminder so unit tests stay deterministic.
class VisitReminderInput {
  const VisitReminderInput({
    required this.visitId,
    required this.scheduledStart,
    required this.status,
  });

  final String visitId;
  final DateTime scheduledStart;
  final String status;
}

class ScheduledReminder {
  const ScheduledReminder({
    required this.visitId,
    required this.fireAt,
  });

  final String visitId;
  final DateTime fireAt;
}

/// Default lead time before [VisitReminderInput.scheduledStart].
const defaultReminderLeadTime = Duration(minutes: 15);

List<ScheduledReminder> planCheckInReminders({
  required List<VisitReminderInput> visits,
  required DateTime now,
  Duration leadTime = defaultReminderLeadTime,
}) {
  final nowUtc = now.toUtc();
  final out = <ScheduledReminder>[];
  for (final v in visits) {
    if (v.status != 'scheduled') continue;
    final start = v.scheduledStart.toUtc();
    final fireAt = start.subtract(leadTime);
    if (!fireAt.isAfter(nowUtc)) continue;
    out.add(ScheduledReminder(visitId: v.visitId, fireAt: fireAt));
  }
  out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return out;
}

/// Port for local OS notifications (stubbed in tests / until plugin wired).
abstract class LocalNotificationPort {
  Future<void> schedule({
    required String id,
    required DateTime fireAt,
    required String title,
    required String body,
  });

  Future<void> cancel(String id);
}

class NoOpLocalNotificationPort implements LocalNotificationPort {
  @override
  Future<void> cancel(String id) async {}

  @override
  Future<void> schedule({
    required String id,
    required DateTime fireAt,
    required String title,
    required String body,
  }) async {}
}
