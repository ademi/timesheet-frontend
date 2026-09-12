import '../data/models/shift_models.dart';

/// Arguments for the Publish group shift wizard (N≥2).
class GroupShiftPublishArgs {
  const GroupShiftPublishArgs({required this.shift});

  final ShiftOut shift;

  static GroupShiftPublishArgs? fromRaw(dynamic raw) {
    if (raw is GroupShiftPublishArgs) return raw;
    if (raw is ShiftOut) return GroupShiftPublishArgs(shift: raw);
    if (raw is Map && raw['shift'] is ShiftOut) {
      return GroupShiftPublishArgs(shift: raw['shift'] as ShiftOut);
    }
    return null;
  }
}
