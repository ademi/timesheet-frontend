import 'package:get/get.dart';

import '../../../core/getx/put_fresh.dart';
import '../../visits/bindings/visits_binding.dart';
import '../data/repositories/shifts_repository.dart';
import '../utils/shift_route_resolve.dart';
import 'group_shift_attendance_controller.dart';

/// Binding for group participant attendance (kept from ios; edit/remove wizards removed).
class GroupShiftAttendanceBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<ShiftsRepository>()) return;
    final shift = resolveShiftFromRoute();
    if (shift == null) return;
    final participant = resolveParticipantFromRoute(shift);
    if (participant == null) return;
    putFresh(
      () => GroupShiftAttendanceController(
        shiftsRepository: Get.find<ShiftsRepository>(),
        args: GroupShiftAttendanceArgs(shift: shift, participant: participant),
      ),
    );
  }
}
