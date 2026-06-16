import 'package:get/get.dart';

import '../controllers/attendance_corrections_controller.dart';
import '../data/repositories/attendance_repository.dart';
import 'attendance_module_binding.dart';

class AttendanceCorrectionsBinding extends Bindings {
  @override
  void dependencies() {
    AttendanceModuleBinding.ensureDependencies();
    Get.lazyPut<AttendanceCorrectionsController>(
      () => AttendanceCorrectionsController(
        repository: Get.find<AttendanceRepository>(),
      ),
    );
  }
}
