import 'package:get/get.dart';

import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../core/getx/put_fresh.dart';
import '../../visits/bindings/visits_binding.dart';
import '../data/repositories/shifts_repository.dart';
import '../utils/shift_route_resolve.dart';
import 'group_shift_travel_args.dart';
import 'group_shift_travel_controller.dart';

class GroupShiftTravelBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<ShiftsRepository>()) return;
    final args =
        GroupShiftTravelArgs.fromRaw(routeArguments()) ??
        () {
          final shift = resolveShiftFromRoute();
          return shift == null ? null : GroupShiftTravelArgs(shift: shift);
        }();
    if (args == null) return;
    putFresh(
      () => GroupShiftTravelController(
        shiftsRepository: Get.find<ShiftsRepository>(),
        args: args,
      ),
    );
  }
}
