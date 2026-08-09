/// Aggregated KPI counts for the staff home dashboard (client-side from list APIs).
class StaffHomeStats {
  const StaffHomeStats({
    this.clientsTotal = 0,
    this.clientsActive = 0,
    this.contractorsTotal = 0,
    this.contractorsActive = 0,
    this.contractorsInvited = 0,
    this.contractorsPendingDocs = 0,
    this.jobsTotal = 0,
    this.jobsOpen = 0,
    this.visitsToday = 0,
    this.visitsScheduledToday = 0,
    this.visitsCompletedToday = 0,
    this.visitsThisWeek = 0,
  });

  final int clientsTotal;
  final int clientsActive;
  final int contractorsTotal;
  final int contractorsActive;
  final int contractorsInvited;
  final int contractorsPendingDocs;
  final int jobsTotal;
  final int jobsOpen;
  final int visitsToday;
  final int visitsScheduledToday;
  final int visitsCompletedToday;
  final int visitsThisWeek;

  static const empty = StaffHomeStats();
}
