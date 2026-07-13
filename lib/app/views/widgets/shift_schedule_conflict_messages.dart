/// User-facing messages for scheduling conflict codes from the API.
String shiftScheduleConflictMessage(String code) {
  switch (code) {
    case 'overlapping_recurring':
      return 'Multiple recurring schedules overlap';
    case 'leave_vs_assignment':
      return 'Employee on leave but also assigned a shift';
    default:
      return code;
  }
}
