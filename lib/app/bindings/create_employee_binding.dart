import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../controllers/create_employee_controller.dart';

class CreateEmployeeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AttendanceApiClient>()) {
      Get.put<AttendanceApiClient>(
        AttendanceApiClient(GetStorage(), Get.find<ApiClient>().plainDio),
        permanent: true,
      );
    }
    Get.lazyPut<CreateEmployeeController>(() => CreateEmployeeController());
  }
}
