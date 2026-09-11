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

/// DELETE with `rebalance=equal` (E2); reason required (D5).
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
        rebalance: 'equal',
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
