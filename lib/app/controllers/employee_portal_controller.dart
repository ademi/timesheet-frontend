import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/attendance_api_client.dart';
import '../data/models/attendance/time_entry_out.dart';
import '../data/models/scheduling/assignment_models.dart';
import '../data/models/scheduling/scheduling_date_utils.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';

class EmployeePortalController extends GetxController {
  void openMyHours() => Get.toNamed(AppRoutes.employeeMyHours);

  void openMySchedule() => Get.toNamed(AppRoutes.employeeMySchedule);
}

class EmployeeMyHoursController extends GetxController {
  EmployeeMyHoursController({required Dio dio}) : _dio = dio;

  final Dio _dio;
  final entries = <TimeEntryOut>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final response = await _dio.get<List<dynamic>>(
        '${AppConstants.apiV1}/attendance/time-entries',
        queryParameters: {
          'from': fmtSchedulingDate(from),
          'to': fmtSchedulingDate(now),
          'limit': 100,
        },
      );
      final data = response.data ?? <dynamic>[];
      entries.assignAll(
        data
            .whereType<Map<String, dynamic>>()
            .map(TimeEntryOut.fromJson)
            .toList(),
      );
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        e.message ?? 'Failed to load hours',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textLight,
      );
    } finally {
      isLoading.value = false;
    }
  }
}

class EmployeeMyScheduleController extends GetxController {
  EmployeeMyScheduleController({required Dio dio}) : _dio = dio;

  final Dio _dio;
  final assignments = <AssignmentOut>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final start = mondayOfWeek(DateTime.now());
      final end = start.add(const Duration(days: 13));
      final response = await _dio.get<List<dynamic>>(
        AppConstants.schedulingMyAssignmentsPath,
        queryParameters: {
          'start': fmtSchedulingDate(start),
          'end': fmtSchedulingDate(end),
        },
      );
      final data = response.data ?? <dynamic>[];
      assignments.assignAll(
        data
            .whereType<Map<String, dynamic>>()
            .map(AssignmentOut.fromJson)
            .toList(),
      );
    } on DioException catch (e) {
      Get.snackbar(
        'Error',
        e.message ?? 'Failed to load schedule',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textLight,
      );
    } finally {
      isLoading.value = false;
    }
  }
}

class EmployeePortalBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(EmployeePortalController.new);
  }
}

class EmployeeMyHoursBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => EmployeeMyHoursController(
        dio: Get.find<AttendanceApiClient>().dio,
      ),
    );
  }
}

class EmployeeMyScheduleBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => EmployeeMyScheduleController(
        dio: Get.find<AttendanceApiClient>().dio,
      ),
    );
  }
}
