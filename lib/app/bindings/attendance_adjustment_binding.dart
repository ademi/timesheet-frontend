import 'package:get/get.dart';

import '../controllers/attendance_adjustment_controller.dart';
import '../data/repositories/attendance_repository.dart';
import 'attendance_module_binding.dart';

class AttendanceAdjustmentBinding extends Bindings {
  @override
  void dependencies() {
    AttendanceModuleBinding.ensureDependencies();
    Get.lazyPut<AttendanceAdjustmentController>(
      () => AttendanceAdjustmentController(
        repository: Get.find<AttendanceRepository>(),
      ),
    );
  }
}
