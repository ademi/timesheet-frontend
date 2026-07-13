enum ShiftSource {
  recurring,
  override,
  leave;

  static ShiftSource? fromApiValue(String? value) {
    switch (value) {
      case 'recurring':
        return ShiftSource.recurring;
      case 'override':
        return ShiftSource.override;
      case 'leave':
        return ShiftSource.leave;
      default:
        return null;
    }
  }

  String get apiValue {
    switch (this) {
      case ShiftSource.recurring:
        return 'recurring';
      case ShiftSource.override:
        return 'override';
      case ShiftSource.leave:
        return 'leave';
    }
  }
}
