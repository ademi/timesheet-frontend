import '../data/models/shift_models.dart';
import '../data/models/shift_travel_models.dart';

class GroupShiftTravelArgs {
  const GroupShiftTravelArgs({required this.shift, this.existing});

  final ShiftOut shift;
  final ShiftTravelOut? existing;

  bool get isEditing => existing != null;

  static GroupShiftTravelArgs? fromRaw(dynamic raw) {
    if (raw is GroupShiftTravelArgs) return raw;
    if (raw is Map && raw['shift'] is ShiftOut) {
      return GroupShiftTravelArgs(
        shift: raw['shift'] as ShiftOut,
        existing: raw['existing'] as ShiftTravelOut?,
      );
    }
    return null;
  }
}
