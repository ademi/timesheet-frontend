import 'payroll_settings.dart';

class PayrollPeriodCandidate {
  const PayrollPeriodCandidate({
    required this.option,
    required this.title,
    required this.periodStart,
    required this.periodEnd,
  });

  final PayrollDefaultCreationOption option;
  final String title;
  final DateTime periodStart;
  final DateTime periodEnd;
}

abstract final class PayrollPeriodCalculator {
  PayrollPeriodCalculator._();

  static List<PayrollPeriodCandidate> buildCandidates({
    required PayrollSettings settings,
    required DateTime today,
  }) {
    final baseToday = _dateOnly(today);

    switch (settings.frequency) {
      case PayrollFrequency.weekly:
        return _buildShiftedCandidates(
          currentStart: _weeklyStart(baseToday, settings.weekStartDay),
          periodLengthDays: 7,
        );
      case PayrollFrequency.biweekly:
        final anchor = settings.biweeklyAnchorDate;
        if (anchor == null) return [];
        return _buildShiftedCandidates(
          currentStart: _biweeklyStart(baseToday, _dateOnly(anchor)),
          periodLengthDays: 14,
        );
      case PayrollFrequency.monthly:
        return _buildMonthlyCandidates(
          today: baseToday,
          monthlyStartDay: settings.monthlyStartDay,
        );
      case PayrollFrequency.custom:
        return [];
    }
  }

  static int expectedLengthDays(PayrollFrequency frequency) {
    switch (frequency) {
      case PayrollFrequency.weekly:
        return 7;
      case PayrollFrequency.biweekly:
        return 14;
      case PayrollFrequency.monthly:
      case PayrollFrequency.custom:
        return 0;
    }
  }

  static List<PayrollPeriodCandidate> _buildShiftedCandidates({
    required DateTime currentStart,
    required int periodLengthDays,
  }) {
    PayrollPeriodCandidate candidate(
      PayrollDefaultCreationOption option,
      String title,
      int shift,
    ) {
      final start = currentStart.add(Duration(days: shift * periodLengthDays));
      final end = start.add(Duration(days: periodLengthDays - 1));
      return PayrollPeriodCandidate(
        option: option,
        title: title,
        periodStart: start,
        periodEnd: end,
      );
    }

    return [
      candidate(PayrollDefaultCreationOption.previous, 'Previous period', -1),
      candidate(PayrollDefaultCreationOption.current, 'Current period', 0),
      candidate(PayrollDefaultCreationOption.next, 'Next period', 1),
    ];
  }

  static List<PayrollPeriodCandidate> _buildMonthlyCandidates({
    required DateTime today,
    required int monthlyStartDay,
  }) {
    final currentStart = _monthlyStartForDate(today, monthlyStartDay);
    final previousStart = _addMonths(currentStart, -1, monthlyStartDay);
    final nextStart = _addMonths(currentStart, 1, monthlyStartDay);

    return [
      PayrollPeriodCandidate(
        option: PayrollDefaultCreationOption.previous,
        title: 'Previous period',
        periodStart: previousStart,
        periodEnd: currentStart.subtract(const Duration(days: 1)),
      ),
      PayrollPeriodCandidate(
        option: PayrollDefaultCreationOption.current,
        title: 'Current period',
        periodStart: currentStart,
        periodEnd: nextStart.subtract(const Duration(days: 1)),
      ),
      PayrollPeriodCandidate(
        option: PayrollDefaultCreationOption.next,
        title: 'Next period',
        periodStart: nextStart,
        periodEnd: _addMonths(
          nextStart,
          1,
          monthlyStartDay,
        ).subtract(const Duration(days: 1)),
      ),
    ];
  }

  static DateTime _weeklyStart(DateTime today, int weekStartDay) {
    final daysSinceStart = (today.weekday - weekStartDay) % 7;
    return today.subtract(Duration(days: daysSinceStart));
  }

  static DateTime _biweeklyStart(DateTime today, DateTime anchor) {
    final diffDays = today.difference(anchor).inDays;
    final blockOffset = (diffDays / 14).floor();
    return anchor.add(Duration(days: blockOffset * 14));
  }

  static DateTime _monthlyStartForDate(DateTime today, int monthlyStartDay) {
    final thisMonthStart = _monthStart(
      today.year,
      today.month,
      monthlyStartDay,
    );
    if (!today.isBefore(thisMonthStart)) return thisMonthStart;
    return _addMonths(thisMonthStart, -1, monthlyStartDay);
  }

  static DateTime _addMonths(DateTime date, int monthOffset, int startDay) {
    final target = DateTime(date.year, date.month + monthOffset);
    return _monthStart(target.year, target.month, startDay);
  }

  static DateTime _monthStart(int year, int month, int startDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final safeDay = startDay.clamp(1, lastDay);
    return DateTime(year, month, safeDay);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
