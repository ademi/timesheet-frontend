import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/attendance/attendance_adjustment_history.dart';
import '../data/models/attendance/attendance_error_model.dart';
import '../data/models/attendance/attendance_exception_model.dart';
import '../data/models/attendance/employee_model.dart';
import '../data/repositories/attendance_repository.dart';
import '../routes/app_navigation.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';

class AttendanceCorrectionsController extends GetxController {
  AttendanceCorrectionsController({required AttendanceRepository repository})
      : _repository = repository;

  final AttendanceRepository _repository;

  final isLoading = false.obs;
  final exceptions = <AttendanceExceptionModel>[].obs;
  final fromDate = Rx<DateTime>(
    DateTime.now().subtract(const Duration(days: 13)),
  );
  final toDate = Rx<DateTime>(DateTime.now());

  final _employeeNames = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadExceptions();
  }

  String employeeName(String employeeId) =>
      _employeeNames[employeeId] ?? 'Employee $employeeId';

  void setFromDate(DateTime date) => fromDate.value = date;

  void setToDate(DateTime date) => toDate.value = date;

  String _formatDateParam(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split('T').first;
  }

  Future<void> loadExceptions() async {
    if (fromDate.value.isAfter(toDate.value)) {
      _showError('From date cannot be after To date.');
      return;
    }
    isLoading.value = true;
    try {
      await _ensureEmployeeNames();
      final list = await _repository.fetchExceptions(
        from: _formatDateParam(fromDate.value),
        to: _formatDateParam(toDate.value),
      );
      exceptions.assignAll(list);
    } on AttendanceErrorModel catch (e) {
      _showError(e.detail);
    } on DioException catch (e) {
      _showError(_dioMessage(e));
    } catch (_) {
      _showError('Failed to load attendance exceptions.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _ensureEmployeeNames() async {
    if (_employeeNames.isNotEmpty) return;
    try {
      final employees = await _repository.fetchEmployees();
      _employeeNames.assignAll({
        for (final EmployeeModel e in employees) e.id: e.fullName,
      });
    } catch (_) {
      // Name resolution is best-effort; ignore failures.
    }
  }

  Future<void> openCorrection(AttendanceExceptionModel exception) async {
    final args = AttendanceAdjustmentArgs.forException(
      exception,
      employeeName: employeeName(exception.employeeId),
    );
    final result = await Get.toNamed(
      AppRoutes.adminAttendanceAdjustment,
      arguments: args,
    );
    if (result == true) {
      await loadExceptions();
    }
  }

  Future<void> createManualEntry() async {
    final picked = await Get.toNamed(
      AppRoutes.employeePicker,
      arguments: const EmployeePickerArgs(title: 'Select Employee'),
    );
    final selected = readTypedResult<EmployeePickerResult>(picked);
    if (selected == null) return;

    final args = AttendanceAdjustmentArgs.manualEntry(
      employeeId: selected.employee.id,
      employeeName: selected.employee.fullName,
    );
    final result = await Get.toNamed(
      AppRoutes.adminAttendanceAdjustment,
      arguments: args,
    );
    if (result == true) {
      await loadExceptions();
    }
  }

  Future<void> showHistory(AttendanceExceptionModel exception) async {
    if (!exception.hasOpenEntry) {
      _showError('No history available for this entry yet.');
      return;
    }
    try {
      final history = await _repository.fetchAdjustmentHistory(exception.id);
      Get.dialog(_HistoryDialog(history: history));
    } on AttendanceErrorModel catch (e) {
      _showError(e.detail);
    } on DioException catch (e) {
      _showError(_dioMessage(e));
    } catch (_) {
      _showError('Failed to load adjustment history.');
    }
  }

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    return e.message ?? 'An unexpected error occurred.';
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
    );
  }
}

class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog({required this.history});

  final List<AttendanceAdjustmentHistory> history;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adjustment History'),
      content: SizedBox(
        width: double.maxFinite,
        child: history.isEmpty
            ? const Text('No adjustments recorded for this entry.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: history.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final h = history[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.action,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (h.reason != null && h.reason!.isNotEmpty)
                        Text(h.reason!),
                      if (h.employeeConfirmationStatus != null)
                        Text('Status: ${h.employeeConfirmationStatus}'),
                      if (h.createdAt != null)
                        Text(
                          h.createdAt!.toLocal().toString().split('.').first,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
