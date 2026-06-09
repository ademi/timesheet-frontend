import 'payroll_date_utils.dart';

enum PayrollFrequency {
  weekly,
  biweekly,
  monthly,
  custom;

  String get label {
    switch (this) {
      case PayrollFrequency.weekly:
        return 'Weekly';
      case PayrollFrequency.biweekly:
        return 'Biweekly';
      case PayrollFrequency.monthly:
        return 'Monthly';
      case PayrollFrequency.custom:
        return 'Custom';
    }
  }

  static PayrollFrequency fromName(String? value) {
    return PayrollFrequency.values.firstWhere(
      (frequency) => frequency.name == value,
      orElse: () => PayrollFrequency.weekly,
    );
  }
}

enum PayrollDefaultCreationOption {
  previous,
  current,
  next;

  String get label {
    switch (this) {
      case PayrollDefaultCreationOption.previous:
        return 'Previous period';
      case PayrollDefaultCreationOption.current:
        return 'Current period';
      case PayrollDefaultCreationOption.next:
        return 'Next period';
    }
  }

  static PayrollDefaultCreationOption fromName(String? value) {
    return PayrollDefaultCreationOption.values.firstWhere(
      (option) => option.name == value,
      orElse: () => PayrollDefaultCreationOption.next,
    );
  }
}

class PayrollSettings {
  const PayrollSettings({
    required this.frequency,
    required this.weekStartDay,
    required this.biweeklyAnchorDate,
    required this.monthlyStartDay,
    required this.defaultCreationOption,
    required this.preventOverlappingPeriods,
  });

  factory PayrollSettings.defaults() {
    return const PayrollSettings(
      frequency: PayrollFrequency.weekly,
      weekStartDay: DateTime.monday,
      biweeklyAnchorDate: null,
      monthlyStartDay: 1,
      defaultCreationOption: PayrollDefaultCreationOption.next,
      preventOverlappingPeriods: true,
    );
  }

  factory PayrollSettings.fromJson(Map<String, dynamic> json) {
    return PayrollSettings(
      frequency: PayrollFrequency.fromName(json['frequency'] as String?),
      weekStartDay: json['week_start_day'] as int? ?? DateTime.monday,
      biweeklyAnchorDate: parsePayrollDateOrNull(json['biweekly_anchor_date']),
      monthlyStartDay: json['monthly_start_day'] as int? ?? 1,
      defaultCreationOption: PayrollDefaultCreationOption.fromName(
        json['default_creation_option'] as String?,
      ),
      preventOverlappingPeriods:
          json['prevent_overlapping_periods'] as bool? ?? true,
    );
  }

  final PayrollFrequency frequency;
  final int weekStartDay;
  final DateTime? biweeklyAnchorDate;
  final int monthlyStartDay;
  final PayrollDefaultCreationOption defaultCreationOption;
  final bool preventOverlappingPeriods;

  Map<String, dynamic> toJson() => {
    'frequency': frequency.name,
    'week_start_day': weekStartDay,
    'biweekly_anchor_date':
        biweeklyAnchorDate == null ? null : fmtPayrollDate(biweeklyAnchorDate!),
    'monthly_start_day': monthlyStartDay,
    'default_creation_option': defaultCreationOption.name,
    'prevent_overlapping_periods': preventOverlappingPeriods,
  };

  PayrollSettings copyWith({
    PayrollFrequency? frequency,
    int? weekStartDay,
    DateTime? biweeklyAnchorDate,
    bool clearBiweeklyAnchorDate = false,
    int? monthlyStartDay,
    PayrollDefaultCreationOption? defaultCreationOption,
    bool? preventOverlappingPeriods,
  }) {
    return PayrollSettings(
      frequency: frequency ?? this.frequency,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      biweeklyAnchorDate:
          clearBiweeklyAnchorDate
              ? null
              : biweeklyAnchorDate ?? this.biweeklyAnchorDate,
      monthlyStartDay: monthlyStartDay ?? this.monthlyStartDay,
      defaultCreationOption:
          defaultCreationOption ?? this.defaultCreationOption,
      preventOverlappingPeriods:
          preventOverlappingPeriods ?? this.preventOverlappingPeriods,
    );
  }
}

String payrollWeekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Monday';
    case DateTime.tuesday:
      return 'Tuesday';
    case DateTime.wednesday:
      return 'Wednesday';
    case DateTime.thursday:
      return 'Thursday';
    case DateTime.friday:
      return 'Friday';
    case DateTime.saturday:
      return 'Saturday';
    case DateTime.sunday:
      return 'Sunday';
    default:
      return 'Monday';
  }
}
