import 'package:get/get.dart';

import '../../clients/bindings/clients_binding.dart';
import '../../visits/bindings/visits_binding.dart';
import '../data/models/shift_models.dart';
import '../data/repositories/shifts_repository.dart';
import 'group_shift_edit_controller.dart';
import 'group_shift_remove_controller.dart';

class GroupShiftEditBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    ClientsBinding.ensureShared();
    if (!Get.isRegistered<ShiftsRepository>()) return;
    final raw = Get.arguments;
    final ShiftOut? shift =
        raw is GroupShiftEditArgs
            ? raw.shift
            : raw is ShiftOut
            ? raw
            : raw is Map && raw['shift'] is ShiftOut
            ? raw['shift'] as ShiftOut
            : null;
    if (shift == null) return;
    Get.put(
      GroupShiftEditController(
        shiftsRepository: Get.find<ShiftsRepository>(),
        args: GroupShiftEditArgs(shift: shift),
      ),
    );
  }
}

class GroupShiftRemoveBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<ShiftsRepository>()) return;
    final raw = Get.arguments;
    GroupShiftRemoveArgs? args;
    if (raw is GroupShiftRemoveArgs) {
      args = raw;
    } else if (raw is Map &&
        raw['shift'] is ShiftOut &&
        raw['participant'] is ShiftParticipantOut) {
      args = GroupShiftRemoveArgs(
        shift: raw['shift'] as ShiftOut,
        participant: raw['participant'] as ShiftParticipantOut,
      );
    }
    if (args == null) return;
    Get.put(
      GroupShiftRemoveController(
        shiftsRepository: Get.find<ShiftsRepository>(),
        args: args,
      ),
    );
  }
}
