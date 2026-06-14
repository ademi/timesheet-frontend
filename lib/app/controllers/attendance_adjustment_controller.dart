import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/attendance/attendance_adjustment_request.dart';
import '../data/models/attendance/attendance_error_model.dart';
import '../data/repositories/attendance_repository.dart';
import '../routes/route_args.dart';

class AttendanceAdjustmentController extends GetxController {
  AttendanceAdjustmentController({required AttendanceRepository repository})
      : _repository = repository;

  final AttendanceRepository _repository;

  late final AttendanceAdjustmentArgs args;

  final reasonController = TextEditingController();
  final clockInAt = Rxn<DateTime>();
  final clockOutAt = Rxn<DateTime>();
  final isSubmitting = false.obs;
  final errorText = ''.obs;

  AdjustmentAction get action => args.action;

  bool get needsClockIn =>
      action == AdjustmentAction.adminCreateManualEntry ||
      action == AdjustmentAction.adminEditEntry;

  bool get needsClockOut => true;

  String get title {
    switch (action) {
      case AdjustmentAction.adminAddClockOut:
        return 'Add Clock-Out';
      case AdjustmentAction.adminCreateManualEntry:
        return 'Manual Time Entry';
      case AdjustmentAction.adminEditEntry:
        return 'Edit Time Entry';
    }
  }

  @override
  void onInit() {
    super.onInit();
    final raw = Get.arguments;
    args = raw as AttendanceAdjustmentArgs;
    clockInAt.value = args.initialClockInAt?.toLocal();
    clockOutAt.value = args.initialClockOutAt?.toLocal();
  }

  void setClockIn(DateTime value) {
    clockInAt.value = value;
    errorText.value = '';
  }

  void setClockOut(DateTime value) {
    clockOutAt.value = value;
    errorText.value = '';
  }

  Future<void> submit() async {
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      errorText.value = 'A reason is required for every correction.';
      return;
    }

    if (needsClockIn && clockInAt.value == null) {
      errorText.value = 'Please select a clock-in time.';
      return;
    }
    if (needsClockOut && clockOutAt.value == null) {
      errorText.value = 'Please select a clock-out time.';
      return;
    }
    if (clockInAt.value != null &&
        clockOutAt.value != null &&
        !clockOutAt.value!.isAfter(clockInAt.value!)) {
      errorText.value = 'Clock-out must be after clock-in.';
      return;
    }

    final request = _buildRequest(reason);
    if (request == null) {
      errorText.value = 'Missing required information for this correction.';
      return;
    }

    isSubmitting.value = true;
    errorText.value = '';
    try {
      await _repository.submitAdjustment(request);
      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Correction submitted. Awaiting employee confirmation.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on AttendanceErrorModel catch (e) {
      errorText.value = e.detail;
    } on DioException catch (e) {
      final data = e.response?.data;
      errorText.value = data is Map && data['detail'] is String
          ? data['detail'] as String
          : e.message ?? 'Failed to submit correction.';
    } catch (_) {
      errorText.value = 'Failed to submit correction.';
    } finally {
      isSubmitting.value = false;
    }
  }

  AttendanceAdjustmentRequest? _buildRequest(String reason) {
    switch (action) {
      case AdjustmentAction.adminAddClockOut:
        if (args.timeEntryId == null || clockOutAt.value == null) return null;
        return AttendanceAdjustmentRequest.addClockOut(
          timeEntryId: args.timeEntryId!,
          clockOutAt: clockOutAt.value!,
          reason: reason,
        );
      case AdjustmentAction.adminCreateManualEntry:
        if (clockInAt.value == null || clockOutAt.value == null) return null;
        return AttendanceAdjustmentRequest.createManualEntry(
          employeeId: args.employeeId,
          clockInAt: clockInAt.value!,
          clockOutAt: clockOutAt.value!,
          reason: reason,
        );
      case AdjustmentAction.adminEditEntry:
        if (args.timeEntryId == null) return null;
        return AttendanceAdjustmentRequest.editEntry(
          timeEntryId: args.timeEntryId!,
          clockInAt: clockInAt.value,
          clockOutAt: clockOutAt.value,
          reason: reason,
        );
    }
  }

  @override
  void onClose() {
    reasonController.dispose();
    super.onClose();
  }
}
