import 'package:get/get.dart';

import '../../visits/bindings/visits_binding.dart';
import '../data/repositories/shifts_repository.dart';
import 'group_shift_travel_args.dart';
import 'group_shift_travel_controller.dart';

class GroupShiftTravelBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    if (!Get.isRegistered<ShiftsRepository>()) return;
    final args = GroupShiftTravelArgs.fromRaw(Get.arguments);
    if (args == null) return;
    Get.put(
      GroupShiftTravelController(
        shiftsRepository: Get.find<ShiftsRepository>(),
        args: args,
      ),
    );
  }
}
