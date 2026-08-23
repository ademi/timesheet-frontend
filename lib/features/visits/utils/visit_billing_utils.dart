import '../data/models/visit_models.dart';

const int maxTaskBillableMinutes = 1440;

/// Scheduled visit window length in whole minutes.
int visitScheduledDurationMinutes(VisitOut visit) {
  final minutes =
      visit.scheduledEnd.difference(visit.scheduledStart).inMinutes;
  return minutes < 0 ? 0 : minutes;
}

/// Sum of [VisitTaskOut.billableMinutes] on tasks that carry an NDIS code.
int codedTaskBillableMinutesTotal(VisitOut visit) {
  var total = 0;
  for (final task in visit.tasks) {
    final code = task.supportItemCode?.trim();
    if (code == null || code.isEmpty) continue;
    total += task.billableMinutes ?? 0;
  }
  return total;
}

bool visitHasCodedTasks(VisitOut visit) => visit.tasks.any(
      (task) => task.supportItemCode?.trim().isNotEmpty == true,
    );

bool taskMinutesExceedVisitDuration(VisitOut visit) =>
    codedTaskBillableMinutesTotal(visit) >
    visitScheduledDurationMinutes(visit);
