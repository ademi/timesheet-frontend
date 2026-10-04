import 'package:get/get.dart';

import '../../../core/getx/put_fresh.dart';
import '../../clients/bindings/clients_binding.dart';
import '../../visits/bindings/visits_binding.dart';
import '../data/repositories/shifts_repository.dart';
import '../utils/shift_route_resolve.dart';
import 'group_shift_attendance_controller.dart';
import 'group_shift_edit_controller.dart';
import 'group_shift_remove_controller.dart';

class GroupShiftEditBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    ClientsBinding.ensureShared();
    if (!Get.isRegistered<ShiftsRepository>()) return;

    final shift = resolveShiftFromRoute();
    if (shift != null) {
      // GoRouter does not dispose GetX controllers; always recreate for the
      // current shift args so edit cannot stick to a prior shift.
      putFresh(
        () => GroupShiftEditController(
          shiftsRepository: Get.find<ShiftsRepository>(),
          args: GroupShiftEditArgs(shift: shift),
        ),
      );
      return;
    }

    // Cold refresh: hydrate from `?id=` then put controller.
    final id = routeParamId();
    if (id == null) return;
    if (Get.isRegistered<GroupShiftEditController>()) {
      final existing = Get.find<GroupShiftEditController>();
      if (existing.args.shift.id == id) return;
      Get.delete<GroupShiftEditController>(force: true);
    }
    // ignore: discarded_futures
    ensureHydratedFromRouteId(id);
  }

  static String? routeParamId() {
    final id = Get.parameters['id'];
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  /// Loads shift by id and registers [GroupShiftEditController] (Phase 4).
  static Future<void> ensureHydratedFromRouteId(String id) async {
    if (!Get.isRegistered<ShiftsRepository>()) return;
    try {
      final shift = await Get.find<ShiftsRepository>().getShift(
        id,
        includeTravel: true,
      );
      if (Get.isRegistered<GroupShiftEditController>()) {
        final existing = Get.find<GroupShiftEditController>();
        if (existing.args.shift.id == id) return;
      }
      putFresh(
        () => GroupShiftEditController(
          shiftsRepository: Get.find<ShiftsRepository>(),
          args: GroupShiftEditArgs(shift: shift),
        ),
      );
    } catch (_) {
      // View shows empty/error until user navigates back.
    }
  }
}

class GroupShiftRemoveBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<ShiftsRepository>()) return;
    final shift = resolveShiftFromRoute();
    if (shift == null) return;
    final participant = resolveParticipantFromRoute(shift);
    if (participant == null) return;
    putFresh(
      () => GroupShiftRemoveController(
        shiftsRepository: Get.find<ShiftsRepository>(),
        args: GroupShiftRemoveArgs(shift: shift, participant: participant),
      ),
    );
  }
}

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
