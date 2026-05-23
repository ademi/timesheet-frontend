import 'payroll_date_utils.dart';

class RateCreateRequest {
  const RateCreateRequest({
    required this.effectiveFrom,
    this.effectiveTo,
    required this.baseRate,
    required this.weekendRate,
    required this.nightRate,
    this.overtimeRate = 0,
    this.overtimeDailyThresholdMinutes,
    this.overtimeWeeklyThresholdMinutes,
    this.nightShiftStart = '22:00',
    this.nightShiftEnd = '06:00',
  });

  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final double baseRate;
  final double weekendRate;
  final double nightRate;
  final double overtimeRate;
  final int? overtimeDailyThresholdMinutes;
  final int? overtimeWeeklyThresholdMinutes;
  final String nightShiftStart;
  final String nightShiftEnd;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'effective_from': fmtPayrollDate(effectiveFrom),
      'base_rate': baseRate,
      'weekend_rate': weekendRate,
      'night_rate': nightRate,
      'overtime_rate': overtimeRate,
      'night_shift_start': nightShiftStart,
      'night_shift_end': nightShiftEnd,
    };
    if (effectiveTo != null) {
      json['effective_to'] = fmtPayrollDate(effectiveTo!);
    }
    if (overtimeDailyThresholdMinutes != null) {
      json['overtime_daily_threshold_minutes'] = overtimeDailyThresholdMinutes;
    }
    if (overtimeWeeklyThresholdMinutes != null) {
      json['overtime_weekly_threshold_minutes'] = overtimeWeeklyThresholdMinutes;
    }
    return json;
  }
}
