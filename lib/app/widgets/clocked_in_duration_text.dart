import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/attendance/employee_model.dart';
import '../../utils/employee_clock_status.dart';

/// Displays live clocked-in duration without forcing the parent list to rebuild (P-04).
class ClockedInDurationText extends StatefulWidget {
  const ClockedInDurationText({
    super.key,
    required this.employee,
    this.style,
    this.asStatusLabel = false,
  });

  final EmployeeModel employee;
  final TextStyle? style;

  /// When true, renders [employeeClockStatusLabel] instead of bare duration.
  final bool asStatusLabel;

  @override
  State<ClockedInDurationText> createState() => _ClockedInDurationTextState();
}

class _ClockedInDurationTextState extends State<ClockedInDurationText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant ClockedInDurationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee.clockedIn != widget.employee.clockedIn ||
        oldWidget.employee.currentClockInAt !=
            widget.employee.currentClockInAt) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.employee.clockedIn) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = formatEmployeeClockDuration(widget.employee);
    final text = widget.asStatusLabel
        ? employeeClockStatusLabel(widget.employee, duration)
        : duration;
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: widget.style);
  }
}
