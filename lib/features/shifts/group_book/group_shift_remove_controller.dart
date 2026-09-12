import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/shift_models.dart';
import '../data/repositories/shifts_repository.dart';
import '../utils/participant_display.dart';

/// Args for full-screen Remove from group.
class GroupShiftRemoveArgs {
  const GroupShiftRemoveArgs({
    required this.shift,
    required this.participant,
  });

  final ShiftOut shift;
  final ShiftParticipantOut participant;
}

/// DELETE with `rebalance=equal` for % groups; `none` when time_based (D4).
class GroupShiftRemoveController extends GetxController {
  GroupShiftRemoveController({
    required ShiftsRepository shiftsRepository,
    required this.args,
    void Function(ShiftOut shift)? onRemoved,
  }) : _shifts = shiftsRepository,
       _onRemoved = onRemoved;

  final ShiftsRepository _shifts;
  final GroupShiftRemoveArgs args;
  final void Function(ShiftOut shift)? _onRemoved;

  final reasonCtrl = TextEditingController();
  final isSaving = false.obs;
  final errorMessage = RxnString();

  int get currentN => activeParticipants(args.shift.participants).length;
  int get nextN => (currentN - 1).clamp(0, 32);

  String get participantName =>
      args.participant.participantName ?? args.participant.participantId;

  /// True when any active participant uses time_based allocation.
  bool get isTimeBasedGroup {
    final active = activeParticipants(args.shift.participants);
    return active.any((p) => p.allocationStrategy == 'time_based');
  }

  String get rebalanceMode => isTimeBasedGroup ? 'none' : 'equal';

  String get rebalanceHint =>
      isTimeBasedGroup
          ? 'Remaining participants keep their time windows unchanged.'
          : 'Remaining participants will be equal-split again.';

  @override
  void onClose() {
    reasonCtrl.dispose();
    super.onClose();
  }

  Future<void> remove() async {
    if (isSaving.value) return;
    errorMessage.value = null;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      errorMessage.value = 'Reason is required.';
      return;
    }

    isSaving.value = true;
    try {
      final updated = await _shifts.removeParticipant(
        args.shift.id,
        args.participant.participantId,
        reason: reason,
        rebalance: rebalanceMode,
      );
      if (_onRemoved != null) {
        _onRemoved(updated);
      } else if (!Get.testMode) {
        Get.back(result: updated);
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) {
        AppToast.error('Could not remove', e.message);
      }
    } catch (e) {
      errorMessage.value = e.toString();
      if (!Get.testMode) {
        AppToast.error('Could not remove', e.toString());
      }
    } finally {
      isSaving.value = false;
    }
  }
}
