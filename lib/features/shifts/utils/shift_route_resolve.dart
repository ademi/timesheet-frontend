import 'package:get/get.dart';

import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../../rostering/domain/roster_composer_args.dart';
import '../../visits/controllers/staff_visits_controller.dart';
import '../data/models/shift_models.dart';
import '../group_book/group_shift_edit_args.dart';
import '../group_travel/group_shift_travel_args.dart';

/// Resolves a [ShiftOut] from GoRouter/GetX route args or the open shift detail.
///
/// Order: [routeArguments] → [StaffVisitsController.selectedShift] matching
/// `?id=`. Used by attendance / travel bindings so in-session navigation stays
/// refresh-tolerant when the board controller still holds the shift.
ShiftOut? resolveShiftFromRoute() {
  final raw = routeArguments();
  if (raw is ShiftOut) return raw;
  if (raw is GroupShiftEditArgs) return raw.shift;
  if (raw is RosterComposerArgs) return raw.shift;
  if (raw is GroupShiftTravelArgs) return raw.shift;
  if (raw is Map && raw['shift'] is ShiftOut) {
    return raw['shift'] as ShiftOut;
  }

  final id = routeParam('id');
  if (id != null && Get.isRegistered<StaffVisitsController>()) {
    final selected = Get.find<StaffVisitsController>().selectedShift.value;
    if (selected != null && selected.id == id) return selected;
  }
  return null;
}

/// Participant from route args map or `?participantId=` against [shift].
ShiftParticipantOut? resolveParticipantFromRoute(ShiftOut shift) {
  final raw = routeArguments();
  if (raw is Map && raw['participant'] is ShiftParticipantOut) {
    return raw['participant'] as ShiftParticipantOut;
  }
  final pid = routeParam('participantId');
  if (pid == null || pid.isEmpty) return null;
  for (final p in shift.participants) {
    if (p.id == pid || p.participantId == pid) return p;
  }
  return null;
}
