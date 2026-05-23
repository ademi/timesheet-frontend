import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/rate_create_request.dart';
import '../data/models/payroll/rate_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../routes/route_args.dart';
import '../themes/app_colors.dart';

class EmployeeRateFormController extends GetxController {
  EmployeeRateFormController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  late final String employeeId;
  late final bool isEdit;
  RateOut? _editingRate;

  final effectiveFrom = Rxn<DateTime>();
  final effectiveTo = Rxn<DateTime>();
  final baseRateController = TextEditingController();
  final weekendRateController = TextEditingController();
  final nightRateController = TextEditingController();
  final overtimeRateController = TextEditingController(text: '0');
  final dailyThresholdController = TextEditingController(text: '480');
  final weeklyThresholdController = TextEditingController(text: '2400');
  final nightShiftStartController = TextEditingController(text: '22:00');
  final nightShiftEndController = TextEditingController(text: '06:00');

  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is! EmployeeRateFormArgs || args.employeeId.isEmpty) {
      Get.back();
      return;
    }
    employeeId = args.employeeId;
    isEdit = args.isEdit;
    if (isEdit && args.rate != null) {
      _populateFromRate(args.rate!);
    } else {
      effectiveFrom.value = DateTime.now();
    }
  }

  void _populateFromRate(RateOut rate) {
    _editingRate = rate;
    effectiveFrom.value = rate.effectiveFrom;
    effectiveTo.value = rate.effectiveTo;
    baseRateController.text = rate.baseRate.toString();
    weekendRateController.text = rate.weekendRate.toString();
    nightRateController.text = rate.nightRate.toString();
    overtimeRateController.text = rate.overtimeRate.toString();
    dailyThresholdController.text =
        rate.overtimeDailyThresholdMinutes.toString();
    weeklyThresholdController.text =
        rate.overtimeWeeklyThresholdMinutes.toString();
    nightShiftStartController.text = rate.nightShiftStart;
    nightShiftEndController.text = rate.nightShiftEnd;
  }

  Future<void> pickEffectiveFrom(BuildContext context) async {
    if (isEdit) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: effectiveFrom.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) effectiveFrom.value = picked;
  }

  Future<void> pickEffectiveTo(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: effectiveTo.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) effectiveTo.value = picked;
  }

  void clearEffectiveTo() => effectiveTo.value = null;

  Future<void> submit() async {
    if (effectiveFrom.value == null) {
      _showError('Effective from is required.');
      return;
    }

    final baseRate = double.tryParse(baseRateController.text.trim());
    final weekendRate = double.tryParse(weekendRateController.text.trim());
    final nightRate = double.tryParse(nightRateController.text.trim());
    if (baseRate == null || weekendRate == null || nightRate == null) {
      _showError('Enter valid rate values.');
      return;
    }

    try {
      isSaving.value = true;
      if (!isEdit) {
        await _repository.createRate(
          employeeId,
          RateCreateRequest(
            effectiveFrom: effectiveFrom.value!,
            effectiveTo: effectiveTo.value,
            baseRate: baseRate,
            weekendRate: weekendRate,
            nightRate: nightRate,
            overtimeRate:
                double.tryParse(overtimeRateController.text.trim()) ?? 0,
            overtimeDailyThresholdMinutes:
                int.tryParse(dailyThresholdController.text.trim()) ?? 480,
            overtimeWeeklyThresholdMinutes:
                int.tryParse(weeklyThresholdController.text.trim()) ?? 2400,
            nightShiftStart: nightShiftStartController.text.trim(),
            nightShiftEnd: nightShiftEndController.text.trim(),
          ),
        );
      } else {
        final body = <String, dynamic>{
          if (effectiveTo.value != null)
            'effective_to': fmtPayrollDate(effectiveTo.value!),
          'base_rate': baseRate,
          'weekend_rate': weekendRate,
          'night_rate': nightRate,
          'overtime_rate':
              double.tryParse(overtimeRateController.text.trim()) ?? 0,
          'overtime_daily_threshold_minutes':
              int.tryParse(dailyThresholdController.text.trim()) ?? 480,
          'overtime_weekly_threshold_minutes':
              int.tryParse(weeklyThresholdController.text.trim()) ?? 2400,
          'night_shift_start': nightShiftStartController.text.trim(),
          'night_shift_end': nightShiftEndController.text.trim(),
        };
        await _repository.updateRate(_editingRate!.id, body);
      }
      Get.back(result: true);
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to save rate.');
    } finally {
      isSaving.value = false;
    }
  }

  String formatDate(DateTime date) => fmtPayrollDate(date);

  String _extractErrorMessage(DioException e) {
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
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
    );
  }

  @override
  void onClose() {
    baseRateController.dispose();
    weekendRateController.dispose();
    nightRateController.dispose();
    overtimeRateController.dispose();
    dailyThresholdController.dispose();
    weeklyThresholdController.dispose();
    nightShiftStartController.dispose();
    nightShiftEndController.dispose();
    super.onClose();
  }
}
