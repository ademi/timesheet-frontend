import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/rate_create_request.dart';
import '../data/models/payroll/rate_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../themes/app_colors.dart';

class EmployeeRatesController extends GetxController {
  EmployeeRatesController({required PayrollRepository repository})
      : _repository = repository;

  final PayrollRepository _repository;

  late final String employeeId;
  final rates = <RateOut>[].obs;
  final isLoading = false.obs;

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

  RateOut? editingRate;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is! String || args.isEmpty) {
      Get.back();
      return;
    }
    employeeId = args;
    loadRates();
  }

  Future<void> loadRates() async {
    try {
      isLoading.value = true;
      rates.assignAll(await _repository.getRates(employeeId));
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load employee rates.');
    } finally {
      isLoading.value = false;
    }
  }

  void openCreateForm() {
    editingRate = null;
    effectiveFrom.value = DateTime.now();
    effectiveTo.value = null;
    baseRateController.clear();
    weekendRateController.clear();
    nightRateController.text = '0';
    dailyThresholdController.text = '480';
    weeklyThresholdController.text = '2400';
    nightShiftStartController.text = '22:00';
    nightShiftEndController.text = '06:00';
    _showRateForm(isEdit: false);
  }

  void openEditForm(RateOut rate) {
    editingRate = rate;
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
    _showRateForm(isEdit: true);
  }

  Future<void> pickEffectiveFrom(BuildContext context) async {
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

  String? validateRequiredDate() {
    if (effectiveFrom.value == null) return 'Effective from is required';
    return null;
  }

  String? validatePositiveNumber(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'This field is required' : null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Must be zero or more';
    return null;
  }

  String? validateTime(String? value) {
    if (value == null || value.trim().isEmpty) return 'Time is required';
    final regex = RegExp(r'^\d{2}:\d{2}$');
    if (!regex.hasMatch(value.trim())) return 'Use HH:MM format';
    return null;
  }

  Future<void> submitRateForm() async {
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
      isLoading.value = true;
      if (editingRate == null) {
        final created = await _repository.createRate(
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
        rates.insert(0, created);
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
        final updated = await _repository.updateRate(editingRate!.id, body);
        final index = rates.indexWhere((r) => r.id == updated.id);
        if (index >= 0) rates[index] = updated;
      }
      Get.back();
      Get.snackbar(
        'Success',
        editingRate == null ? 'Rate created.' : 'Rate updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textLight,
      );
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to save rate.');
    } finally {
      isLoading.value = false;
    }
  }

  void _showRateForm({required bool isEdit}) {
    Get.bottomSheet(
      Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(Get.context!).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Edit Rate' : 'Create Rate',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Obx(
                () => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Effective From'),
                  subtitle: Text(
                    effectiveFrom.value != null
                        ? fmtPayrollDate(effectiveFrom.value!)
                        : 'Tap to select',
                  ),
                  trailing: isEdit ? null : const Icon(Icons.calendar_today),
                  onTap: isEdit
                      ? null
                      : () => pickEffectiveFrom(Get.context!),
                ),
              ),
              Obx(
                () => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Effective To (optional)'),
                  subtitle: Text(
                    effectiveTo.value != null
                        ? fmtPayrollDate(effectiveTo.value!)
                        : 'No end date',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (effectiveTo.value != null)
                        IconButton(
                          onPressed: clearEffectiveTo,
                          icon: const Icon(Icons.close),
                        ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                  onTap: () => pickEffectiveTo(Get.context!),
                ),
              ),
              TextField(
                controller: baseRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Base Rate'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weekendRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weekend Rate'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nightRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Night Rate'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: overtimeRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Overtime Rate'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dailyThresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Daily OT Threshold (mins)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weeklyThresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weekly OT Threshold (mins)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nightShiftStartController,
                decoration: const InputDecoration(labelText: 'Night Start'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nightShiftEndController,
                decoration: const InputDecoration(labelText: 'Night End'),
              ),
              const SizedBox(height: 16),
              Obx(
                () => ElevatedButton(
                  onPressed: isLoading.value ? null : submitRateForm,
                  child: isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Update Rate' : 'Create Rate'),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
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
