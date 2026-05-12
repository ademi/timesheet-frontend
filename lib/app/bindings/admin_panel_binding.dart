import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../controllers/admin_panel_controller.dart';
import '../controllers/attendance_report_controller.dart';
import '../controllers/employee_management_controller.dart';

class AdminPanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdminPanelController>(() => AdminPanelController());
    Get.lazyPut<AttendanceReportController>(() => AttendanceReportController());

    if (!Get.isRegistered<AttendanceApiClient>()) {
      Get.put<AttendanceApiClient>(
        AttendanceApiClient(GetStorage(), Get.find<ApiClient>().plainDio),
        permanent: true,
      );
    }

    Get.lazyPut<EmployeeManagementController>(
      EmployeeManagementController.createDefault,
    );
  }
}
