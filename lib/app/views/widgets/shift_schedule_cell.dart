import 'package:flutter/material.dart';

import '../../data/models/scheduling/board_day.dart';
import '../../data/models/scheduling/shift_source.dart';
import '../../data/models/scheduling/shift_status.dart';
import '../../themes/app_colors.dart';
import 'shift_schedule_conflict_messages.dart';
import 'shift_schedule_utils.dart';

class ShiftScheduleCell extends StatelessWidget {
  const ShiftScheduleCell({
    super.key,
    required this.day,
    this.templateColor,
    this.onTap,
    this.isTodayColumn = false,
    this.expandWidth = false,
  });

  final BoardDay day;
  final Color? templateColor;
  final VoidCallback? onTap;
  final bool isTodayColumn;
  final bool expandWidth;

  static const double minWidth = 84;
  static const double minHeight = 52;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _tooltipMessage(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: expandWidth ? double.infinity : minWidth,
            height: minHeight,
            child: Stack(
              children: [
                Positioned.fill(child: _buildBackground()),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: _buildContent(),
                  ),
                ),
                if (day.source == ShiftSource.override)
                  const Positioned(
                    top: 4,
                    left: 4,
                    child: Icon(Icons.circle, size: 6, color: AppColors.textDark),
                  ),
                if (day.conflicts.isNotEmpty) _buildConflictBadge(),
                if (isTodayColumn && day.status == ShiftStatus.assigned)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: _buildTodayAttendanceDot(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _tooltipMessage() {
    final parts = <String>[];
    parts.add(_statusLabel(day.status));
    if (day.templateName != null && day.templateName!.isNotEmpty) {
      parts.add(day.templateName!);
    }
    final start = formatTimeOfDay(day.shiftStart);
    final end = formatTimeOfDay(day.shiftEnd);
    if (start.isNotEmpty && end.isNotEmpty) {
      parts.add('$start – $end');
    }
    if (day.conflicts.isNotEmpty) {
      parts.add(shiftScheduleConflictMessage(day.conflicts.first));
    }
    return parts.join('\n');
  }

  Widget _buildBackground() {
    switch (day.status) {
      case ShiftStatus.assigned:
        final bg = templateColor ?? AppColors.primary;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bg.withValues(alpha: 0.45)),
          ),
        );
      case ShiftStatus.onLeave:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: AppColors.slate200),
              CustomPaint(painter: _DiagonalStripePainter()),
            ],
          ),
        );
      case ShiftStatus.unassigned:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.accentAlt.withValues(alpha: 0.45),
              style: BorderStyle.solid,
            ),
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: AppColors.accentAlt.withValues(alpha: 0.5),
            ),
          ),
        );
      case ShiftStatus.dayOff:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate300),
          ),
        );
    }
  }

  Widget _buildContent() {
    switch (day.status) {
      case ShiftStatus.assigned:
        final name = day.templateName ?? 'Shift';
        final time = _timeLine();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            if (time.isNotEmpty)
              Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
          ],
        );
      case ShiftStatus.onLeave:
        return const Align(
          alignment: Alignment.center,
          child: Text(
            'Leave',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.slate600,
            ),
          ),
        );
      case ShiftStatus.unassigned:
        return const SizedBox.shrink();
      case ShiftStatus.dayOff:
        return const Align(
          alignment: Alignment.center,
          child: Text(
            'Off',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        );
    }
  }

  String _timeLine() {
    final start = formatTimeOfDay(day.shiftStart);
    final end = formatTimeOfDay(day.shiftEnd);
    if (start.isEmpty || end.isEmpty) return '';
    return '$start–$end';
  }

  Widget _buildConflictBadge() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(6),
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '!',
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildTodayAttendanceDot() {
    Color fill;
    Color border;
    if (day.isLate == true) {
      fill = AppColors.error;
      border = AppColors.error;
    } else if (day.clockedIn == true) {
      fill = const Color(0xFF2E7D32);
      border = const Color(0xFF2E7D32);
    } else {
      fill = Colors.transparent;
      border = AppColors.slate500;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
    );
  }

  static String _statusLabel(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.assigned:
        return 'Assigned';
      case ShiftStatus.onLeave:
        return 'On leave';
      case ShiftStatus.unassigned:
        return 'Unassigned';
      case ShiftStatus.dayOff:
        return 'Day off';
    }
  }
}

class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.slate400.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 7.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(7),
    );
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          paint,
        );
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
