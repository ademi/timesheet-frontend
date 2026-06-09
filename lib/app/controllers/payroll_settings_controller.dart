import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/payroll_settings.dart';
import '../data/services/payroll_settings_storage.dart';
import '../themes/app_colors.dart';

class PayrollSettingsController extends GetxController {
  PayrollSettingsController({required PayrollSettingsStorage storage})
    : _storage = storage;

  final PayrollSettingsStorage _storage;

  final frequency = PayrollFrequency.weekly.obs;
  final weekStartDay = DateTime.monday.obs;
  final biweeklyAnchorDate = Rxn<DateTime>();
  final monthlyStartDay = 1.obs;
  final defaultCreationOption = PayrollDefaultCreationOption.next.obs;
  final preventOverlappingPeriods = true.obs;
  final isSaving = false.obs;
  final hasExistingSettings = false.obs;

  @override
  void onInit() {
    super.onInit();
    final settings = _storage.readSettings();
    hasExistingSettings.value = settings != null;
    _applySettings(settings ?? PayrollSettings.defaults());
  }

  void setFrequency(PayrollFrequency value) {
    frequency.value = value;
  }

  Future<void> pickBiweeklyAnchorDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: biweeklyAnchorDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      biweeklyAnchorDate.value = DateTime(
        picked.year,
        picked.month,
        picked.day,
      );
    }
  }

  Future<void> save() async {
    if (frequency.value == PayrollFrequency.biweekly &&
        biweeklyAnchorDate.value == null) {
      _showError('Please select the first known biweekly period start date.');
      return;
    }

    try {
      isSaving.value = true;
      await _storage.saveSettings(
        PayrollSettings(
          frequency: frequency.value,
          weekStartDay: weekStartDay.value,
          biweeklyAnchorDate: biweeklyAnchorDate.value,
          monthlyStartDay: monthlyStartDay.value,
          defaultCreationOption: defaultCreationOption.value,
          preventOverlappingPeriods: preventOverlappingPeriods.value,
        ),
      );
      Get.snackbar(
        'Success',
        'Payroll settings saved.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textLight,
      );
      Get.back(result: true);
    } finally {
      isSaving.value = false;
    }
  }

  String formatDate(DateTime date) => fmtPayrollDate(date);

  void _applySettings(PayrollSettings settings) {
    frequency.value = settings.frequency;
    weekStartDay.value = settings.weekStartDay;
    biweeklyAnchorDate.value = settings.biweeklyAnchorDate;
    monthlyStartDay.value = settings.monthlyStartDay;
    defaultCreationOption.value = settings.defaultCreationOption;
    preventOverlappingPeriods.value = settings.preventOverlappingPeriods;
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
}
