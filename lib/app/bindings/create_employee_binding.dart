import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/network/attendance_api_client.dart';
import '../../core/services/token_storage.dart';
import '../controllers/create_employee_controller.dart';

class CreateEmployeeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AttendanceApiClient>()) {
      Get.put<AttendanceApiClient>(
        AttendanceApiClient(
          Get.find<TokenStorage>(),
          Get.find<ApiClient>().plainDio,
        ),
        permanent: true,
      );
    }
    Get.lazyPut<CreateEmployeeController>(() => CreateEmployeeController());
  }
}
