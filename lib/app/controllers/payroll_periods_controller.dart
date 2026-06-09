import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/payroll/payroll_date_utils.dart';
import '../data/models/payroll/payroll_period_calculator.dart';
import '../data/models/payroll/payroll_settings.dart';
import '../data/models/payroll/period_create_request.dart';
import '../data/models/payroll/period_out.dart';
import '../data/repositories/payroll_repository.dart';
import '../data/services/payroll_settings_storage.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';

class PayrollPeriodsController extends GetxController {
  PayrollPeriodsController({
    required PayrollRepository repository,
    required PayrollSettingsStorage settingsStorage,
  }) : _repository = repository,
       _settingsStorage = settingsStorage;

  final PayrollRepository _repository;
  final PayrollSettingsStorage _settingsStorage;

  final periods = <PeriodOut>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadPeriods();
  }

  Future<void> loadPeriods() async {
    try {
      isLoading.value = true;
      final list = await _repository.getPeriods();
      periods.assignAll(list);
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load payroll periods.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openCreatePeriodSheet(BuildContext context) async {
    final settings = await _ensureSettings(context);
    if (settings == null || !context.mounted) return;

    if (settings.frequency == PayrollFrequency.custom) {
      await createCustomPeriod(context, settings: settings);
      return;
    }

    final candidates = PayrollPeriodCalculator.buildCandidates(
      settings: settings,
      today: DateTime.now(),
    );
    if (candidates.isEmpty) {
      await createCustomPeriod(context, settings: settings);
      return;
    }

    var selected = _defaultCandidate(
      candidates,
      settings.defaultCreationOption,
    );
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Payroll Period',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _settingsSummary(settings),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quick options',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...candidates.map(
                      (candidate) => RadioListTile<PayrollPeriodCandidate>(
                        contentPadding: EdgeInsets.zero,
                        value: candidate,
                        groupValue: selected,
                        activeColor: AppColors.primary,
                        title: Text(candidate.title),
                        subtitle: Text(_formatRange(candidate)),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selected = value);
                          }
                        },
                      ),
                    ),
                    const Divider(height: 24),
                    OutlinedButton.icon(
                      onPressed:
                          () => Navigator.of(
                            sheetContext,
                          ).pop(_CreatePeriodAction.custom),
                      icon: const Icon(Icons.date_range),
                      label: const Text('Custom date range'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(selected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                      ),
                      child: const Text('Create Period'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked == null || !context.mounted) return;
    if (picked == _CreatePeriodAction.custom) {
      await createCustomPeriod(context, settings: settings);
      return;
    }
    if (picked is! PayrollPeriodCandidate) return;
    await createPeriodFromDates(
      context,
      start: picked.periodStart,
      end: picked.periodEnd,
      settings: settings,
    );
  }

  Future<void> createCustomPeriod(
    BuildContext context, {
    PayrollSettings? settings,
  }) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (range == null || !context.mounted) return;

    await createPeriodFromDates(
      context,
      start: range.start,
      end: range.end,
      settings: settings ?? _settingsStorage.readSettings(),
    );
  }

  Future<void> createPeriodFromDates(
    BuildContext context, {
    required DateTime start,
    required DateTime end,
    PayrollSettings? settings,
  }) async {
    final periodStart = _dateOnly(start);
    final periodEnd = _dateOnly(end);
    final validationError = _validatePeriod(
      start: periodStart,
      end: periodEnd,
      settings: settings,
    );
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    if (_requiresDateConfirmation(periodStart) && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Confirm payroll period'),
              content: Text(
                'You are creating a payroll period far from today:\n'
                '${formatDate(periodStart)} → ${formatDate(periodEnd)}\n\n'
                'Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }

    try {
      isLoading.value = true;
      final created = await _repository.createPeriod(
        PeriodCreateRequest(periodStart: periodStart, periodEnd: periodEnd),
      );
      periods.insert(0, created);
      Get.snackbar(
        'Success',
        'Payroll period created.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: AppColors.textLight,
      );
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to create payroll period.');
    } finally {
      isLoading.value = false;
    }
  }

  void openPeriodDetail(PeriodOut period) {
    Get.toNamed(AppRoutes.payrollPeriodDetail, arguments: period);
  }

  void openSettings() {
    Get.toNamed(AppRoutes.payrollSettings);
  }

  String formatDate(DateTime date) => fmtPayrollDate(date);

  Color statusColor(String status) {
    switch (status) {
      case 'calculated':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

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

  Future<PayrollSettings?> _ensureSettings(BuildContext context) async {
    final existing = _settingsStorage.readSettings();
    if (existing != null) return existing;

    final setup = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Set up payroll schedule'),
            content: const Text(
              'Create payroll settings first so the app can suggest accurate '
              'weekly, biweekly, or monthly periods.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Set Up'),
              ),
            ],
          ),
    );
    if (setup != true) return null;

    final saved = await Get.toNamed(AppRoutes.payrollSettings);
    if (saved == true) return _settingsStorage.readSettings();
    return null;
  }

  PayrollPeriodCandidate _defaultCandidate(
    List<PayrollPeriodCandidate> candidates,
    PayrollDefaultCreationOption defaultOption,
  ) {
    return candidates.firstWhere(
      (candidate) => candidate.option == defaultOption,
      orElse: () => candidates.last,
    );
  }

  String _settingsSummary(PayrollSettings settings) {
    switch (settings.frequency) {
      case PayrollFrequency.weekly:
        return 'Weekly, starts on ${payrollWeekdayLabel(settings.weekStartDay)}';
      case PayrollFrequency.biweekly:
        final anchor = settings.biweeklyAnchorDate;
        return anchor == null
            ? 'Biweekly'
            : 'Biweekly, anchored on ${formatDate(anchor)}';
      case PayrollFrequency.monthly:
        return settings.monthlyStartDay == 1
            ? 'Monthly, calendar month'
            : 'Monthly, starts on day ${settings.monthlyStartDay}';
      case PayrollFrequency.custom:
        return 'Custom date range';
    }
  }

  String _formatRange(PayrollPeriodCandidate candidate) {
    return '${formatDate(candidate.periodStart)} → '
        '${formatDate(candidate.periodEnd)}';
  }

  String? _validatePeriod({
    required DateTime start,
    required DateTime end,
    PayrollSettings? settings,
  }) {
    if (end.isBefore(start)) {
      return 'End date must be on or after start date.';
    }

    for (final period in periods) {
      if (_sameDate(period.periodStart, start) &&
          _sameDate(period.periodEnd, end)) {
        return 'This payroll period already exists.';
      }
    }

    if (settings?.preventOverlappingPeriods ?? true) {
      for (final period in periods) {
        if (_periodsOverlap(
          startA: start,
          endA: end,
          startB: _dateOnly(period.periodStart),
          endB: _dateOnly(period.periodEnd),
        )) {
          return 'This payroll period overlaps an existing period.';
        }
      }
    }

    final frequency = settings?.frequency;
    if (frequency != null) {
      final expectedDays = PayrollPeriodCalculator.expectedLengthDays(
        frequency,
      );
      final actualDays = end.difference(start).inDays + 1;
      if (expectedDays > 0 && actualDays != expectedDays) {
        return '${frequency.label} payroll periods must be exactly '
            '$expectedDays days.';
      }
    }

    final totalDays = end.difference(start).inDays + 1;
    if (totalDays > 366) {
      return 'Payroll period is too long.';
    }

    return null;
  }

  bool _requiresDateConfirmation(DateTime start) {
    final today = _dateOnly(DateTime.now());
    final earliest = today.subtract(const Duration(days: 183));
    final latest = today.add(const Duration(days: 183));
    return start.isBefore(earliest) || start.isAfter(latest);
  }

  bool _periodsOverlap({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    return !startA.isAfter(endB) && !startB.isAfter(endA);
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

enum _CreatePeriodAction { custom }
