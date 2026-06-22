import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/rate_create_request.dart';
import '../data/models/payroll/rate_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../themes/app_colors.dart';

class EmployeeRateFormController extends GetxController {
  EmployeeRateFormController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  late final String employeeId;
  late final bool isEdit;
  late final bool finishCreateFlowOnSave;
  RateOut? _editingRate;

  final effectiveFrom = Rxn<DateTime>();
  final effectiveTo = Rxn<DateTime>();
  final baseRateController = TextEditingController();
  final weekendRateController = TextEditingController();
  final nightRateController = TextEditingController();
  final overtimeRateController = TextEditingController();
  final dailyThresholdController = TextEditingController();
  final weeklyThresholdController = TextEditingController();
  final nightShiftStartController = TextEditingController(text: '22:00');
  final nightShiftEndController = TextEditingController(text: '06:00');

  final isSaving = false.obs;

  VoidCallback? onSavedInPane;

  @override
  void onInit() {
    super.onInit();
    if (!bindFromArgs(Get.arguments)) {
      Get.back();
    }
  }

  /// Binds route args. Returns false when args are invalid.
  bool bindFromArgs(Object? args) {
    if (args is! EmployeeRateFormArgs || args.employeeId.isEmpty) {
      return false;
    }
    employeeId = args.employeeId;
    isEdit = args.isEdit;
    finishCreateFlowOnSave = args.finishCreateFlowOnSave;
    if (isEdit && args.rate != null) {
      _populateFromRate(args.rate!);
    } else {
      effectiveFrom.value = DateTime.now();
    }
    return true;
  }

  /// Copies base rate into weekend, night, and overtime after base rate editing.
  void applyBaseRateToDerivedRates() => _applyBaseRateToDerivedRates();

  void _applyBaseRateToDerivedRates() {
    final base = baseRateController.text.trim();
    if (base.isEmpty) return;
    _fillIfEmpty(weekendRateController, base);
    _fillIfEmpty(nightRateController, base);
    _fillIfEmpty(overtimeRateController, base);
  }

  void _fillIfEmpty(TextEditingController target, String value) {
    if (target.text.trim().isEmpty) {
      target.text = value;
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
        rate.overtimeDailyThresholdMinutes?.toString() ?? '';
    weeklyThresholdController.text =
        rate.overtimeWeeklyThresholdMinutes?.toString() ?? '';
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

  int? _parseOptionalThreshold(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

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

    final dailyThreshold = _parseOptionalThreshold(dailyThresholdController.text);
    final weeklyThreshold = _parseOptionalThreshold(weeklyThresholdController.text);

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
            overtimeDailyThresholdMinutes: dailyThreshold,
            overtimeWeeklyThresholdMinutes: weeklyThreshold,
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
          'overtime_daily_threshold_minutes': dailyThreshold,
          'overtime_weekly_threshold_minutes': weeklyThreshold,
          'night_shift_start': nightShiftStartController.text.trim(),
          'night_shift_end': nightShiftEndController.text.trim(),
        };
        await _repository.updateRate(_editingRate!.id, body);
      }
      _completeSubmitNavigation();
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to save rate.');
    } finally {
      isSaving.value = false;
    }
  }

  void _completeSubmitNavigation() {
    if (onSavedInPane != null) {
      onSavedInPane!();
      return;
    }
    Get.back(result: true);
    if (finishCreateFlowOnSave &&
        !isEdit &&
        Get.currentRoute == AppRoutes.createEmployee) {
      Get.back(result: true);
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
