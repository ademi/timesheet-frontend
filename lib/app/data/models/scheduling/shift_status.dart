enum ShiftStatus {
  assigned,
  onLeave,
  unassigned,
  dayOff;

  static ShiftStatus fromApiValue(String? value) {
    switch (value) {
      case 'assigned':
        return ShiftStatus.assigned;
      case 'on_leave':
        return ShiftStatus.onLeave;
      case 'unassigned':
        return ShiftStatus.unassigned;
      case 'day_off':
        return ShiftStatus.dayOff;
      default:
        return ShiftStatus.unassigned;
    }
  }

  String get apiValue {
    switch (this) {
      case ShiftStatus.assigned:
        return 'assigned';
      case ShiftStatus.onLeave:
        return 'on_leave';
      case ShiftStatus.unassigned:
        return 'unassigned';
      case ShiftStatus.dayOff:
        return 'day_off';
    }
  }
}
