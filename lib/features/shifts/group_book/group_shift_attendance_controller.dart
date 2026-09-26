import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/shift_models.dart';
import '../data/repositories/shifts_repository.dart';
import '../utils/participant_display.dart';

/// Args for full-screen billing attendance (B10).
class GroupShiftAttendanceArgs {
  const GroupShiftAttendanceArgs({
    required this.shift,
    required this.participant,
  });

  final ShiftOut shift;
  final ShiftParticipantOut participant;
}

/// PATCH present | no_show | partial without soft-removing membership.
class GroupShiftAttendanceController extends GetxController {
  GroupShiftAttendanceController({
    required ShiftsRepository shiftsRepository,
    required this.args,
    void Function(ShiftOut shift)? onSaved,
  }) : _shifts = shiftsRepository,
       _onSaved = onSaved;

  final ShiftsRepository _shifts;
  final GroupShiftAttendanceArgs args;
  final void Function(ShiftOut shift)? _onSaved;

  final reasonCtrl = TextEditingController();
  final attendedMinutesCtrl = TextEditingController();
  final attendance = 'present'.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  String get participantName =>
      args.participant.participantName ?? args.participant.participantId;

  int get activeN => activeParticipants(args.shift.participants).length;

  int get billableNBefore {
    final rows = activeParticipants(args.shift.participants);
    return rows.where((p) => p.isBillable).length;
  }

  int get billableNAfter {
    final next = attendance.value;
    final rows = activeParticipants(args.shift.participants);
    var n = 0;
    for (final p in rows) {
      final isTarget = p.participantId == args.participant.participantId;
      final att = isTarget ? next : p.attendance;
      if (att != 'no_show') n++;
    }
    return n;
  }

  bool get showAttendedMinutes => attendance.value == 'partial';

  /// One worker clocks the visit for the whole group (N≥2).
  String get oneClockHint =>
      activeN >= 2
          ? 'One worker still clocks this visit for the whole group. '
              'Attendance only changes who is billed (N / quantity), not the clock.'
          : 'Attendance changes billing presence only; the visit clock is unchanged.';

  String get exportNHint =>
      'Billable N at export: $billableNBefore → $billableNAfter '
      '(no-show stays on the roster but drops from ÷N).';

  @override
  void onInit() {
    super.onInit();
    attendance.value = args.participant.attendance;
    final minutes = args.participant.attendedMinutes;
    if (minutes != null) {
      attendedMinutesCtrl.text = '$minutes';
    }
  }

  @override
  void onClose() {
    reasonCtrl.dispose();
    attendedMinutesCtrl.dispose();
    super.onClose();
  }

  void setAttendance(String value) {
    attendance.value = value;
    errorMessage.value = null;
  }

  Future<void> save() async {
    if (isSaving.value) return;
    errorMessage.value = null;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      errorMessage.value = 'Reason is required.';
      return;
    }

    int? attendedMinutes;
    if (attendance.value == 'partial') {
      final raw = attendedMinutesCtrl.text.trim();
      attendedMinutes = int.tryParse(raw);
      if (attendedMinutes == null || attendedMinutes < 0) {
        errorMessage.value = 'Attended minutes are required for partial.';
        return;
      }
    }

    isSaving.value = true;
    try {
      final updated = await _shifts.setParticipantAttendance(
        args.shift.id,
        args.participant.participantId,
        attendance: attendance.value,
        reason: reason,
        attendedMinutes: attendedMinutes,
      );
      if (_onSaved != null) {
        _onSaved(updated);
      } else if (!Get.testMode) {
        Get.back(result: updated);
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) {
        AppToast.error('Could not update attendance', e.message);
      }
    } catch (e) {
      errorMessage.value = e.toString();
      if (!Get.testMode) {
        AppToast.error('Could not update attendance', e.toString());
      }
    } finally {
      isSaving.value = false;
    }
  }
}
