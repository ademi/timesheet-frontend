import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/services/session_service.dart';
import '../data/attendance_review_models.dart';
import '../data/repositories/attendance_repository.dart';

/// Visit-detail deep link when a pending GPS exception or sync conflict exists.
class VisitAttendanceReviewBanner extends StatefulWidget {
  const VisitAttendanceReviewBanner({super.key, required this.visitId});

  final String visitId;

  @override
  State<VisitAttendanceReviewBanner> createState() =>
      _VisitAttendanceReviewBannerState();
}

class _VisitAttendanceReviewBannerState
    extends State<VisitAttendanceReviewBanner> {
  List<AttendanceReviewItem> _pending = const [];
  bool _loading = false;

  bool get _canReview {
    if (!Get.isRegistered<SessionService>()) return false;
    final session = Get.find<SessionService>();
    return session.hasAny([
      AppPermissions.attendanceAdjust,
      AppPermissions.visitsManage,
    ]);
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant VisitAttendanceReviewBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visitId != widget.visitId) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!_canReview || !Get.isRegistered<AttendanceRepository>()) {
      if (mounted) setState(() => _pending = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final items = await Get.find<AttendanceRepository>().pendingForVisit(
        widget.visitId,
      );
      if (!mounted) return;
      setState(() {
        _pending = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pending = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canReview) return const SizedBox.shrink();
    if (_loading && _pending.isEmpty) return const SizedBox.shrink();
    if (_pending.isEmpty) return const SizedBox.shrink();

    final hasGps = _pending.any(
      (i) => i.kind == AttendanceReviewKind.exception,
    );
    final hasSync = _pending.any(
      (i) => i.kind == AttendanceReviewKind.syncConflict,
    );
    final label = switch ((hasGps, hasSync)) {
      (true, true) => 'Pending GPS + sync review',
      (true, false) => 'Pending GPS exception',
      (false, true) => 'Pending sync conflict',
      _ => 'Pending attendance review',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap:
              () => Get.toNamed(
                AppRoutes.staffAttendanceReview,
                arguments: {'visitId': widget.visitId},
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.fact_check_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(label)),
                Text(
                  'Review',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
