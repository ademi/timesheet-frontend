import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/shift_models.dart';
import '../data/repositories/shifts_repository.dart';
import '../utils/allocation_math.dart';
import '../utils/group_participant_draft.dart';
import '../utils/participant_display.dart';
import '../utils/participant_window_math.dart';
import 'group_shift_windows_view.dart';

/// Args for full-screen Edit group (draft only).
class GroupShiftEditArgs {
  const GroupShiftEditArgs({required this.shift});

  final ShiftOut shift;
}

/// Local draft → one [ShiftsRepository.putParticipants] on Save (E4 / D3).
class GroupShiftEditController extends GetxController {
  GroupShiftEditController({
    required ShiftsRepository shiftsRepository,
    required this.args,
    void Function(ShiftOut shift)? onSaved,
    Future<bool> Function(int nextN)? confirmLargeGroup,
    Future<List<ParticipantWindowDraft>?> Function(
      GroupShiftWindowsArgs args,
    )?
    openWindowsEditor,
  }) : _shifts = shiftsRepository,
       _onSaved = onSaved,
       _confirmLargeGroup = confirmLargeGroup,
       _openWindowsEditor = openWindowsEditor;

  final ShiftsRepository _shifts;
  final GroupShiftEditArgs args;
  final void Function(ShiftOut shift)? _onSaved;
  final Future<bool> Function(int nextN)? _confirmLargeGroup;
  final Future<List<ParticipantWindowDraft>?> Function(
    GroupShiftWindowsArgs args,
  )?
  _openWindowsEditor;

  final draft = GroupParticipantDraftSet(equalSplit: true).obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  DateTime get shiftStart => args.shift.scheduledStart;
  DateTime get shiftEnd => args.shift.scheduledEnd;

  bool get isTimeBased => draft.value.isTimeBased;

  String get remainingLabel => remainingCapacityLabel(
    draft.value.participants.map((p) => p.allocationValue),
  );

  @override
  void onInit() {
    super.onInit();
    _hydrateFromShift(args.shift);
  }

  void _hydrateFromShift(ShiftOut shift) {
    final active = activeParticipants(shift.participants);
    final timeBased =
        active.isNotEmpty &&
        active.every((p) => p.allocationStrategy == 'time_based');
    if (timeBased) {
      draft.value = GroupParticipantDraftSet(
        equalSplit: false,
        allocationStrategy: GroupAllocationStrategy.timeBased,
        participants: [
          for (final p in active)
            GroupParticipantDraft(
              participantId: p.participantId,
              displayName: p.participantName ?? p.participantId,
              allocationValue: 0,
              isHostIncluded: p.participantId == shift.clientId,
              timeWindows: [
                for (final w in p.timeWindows ?? const <ShiftParticipantAllocationOut>[])
                  ParticipantWindowDraft(
                    start: w.participantStartTime,
                    end: w.participantEndTime,
                  ),
              ],
            ),
        ],
      );
      return;
    }

    final values = active.map((p) => p.allocationValue ?? 0.0).toList();
    final equal =
        active.isNotEmpty && sumsTo100(values) && looksEqualSplit(values);
    var next = GroupParticipantDraftSet(
      equalSplit: equal,
      allocationStrategy: GroupAllocationStrategy.percentage,
      participants: [
        for (final p in active)
          GroupParticipantDraft(
            participantId: p.participantId,
            displayName: p.participantName ?? p.participantId,
            allocationValue: p.allocationValue ?? 0,
            isHostIncluded: p.participantId == shift.clientId,
          ),
      ],
    );
    if (equal) next = next.recomputeEqualSplit();
    draft.value = next;
  }

  void setAllocationStrategy(String strategy) {
    draft.value = draft.value.withAllocationStrategy(
      strategy,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
    );
    errorMessage.value = null;
  }

  void setEqualSplit(bool enabled) {
    draft.value = draft.value.withEqualSplit(enabled);
    errorMessage.value = null;
  }

  void setAllocation(String participantId, double value) {
    draft.value = draft.value.setAllocation(participantId, value);
  }

  void removeParticipant(String participantId) {
    draft.value = draft.value.remove(participantId);
  }

  Future<void> editWindows(GroupParticipantDraft row) async {
    final args = GroupShiftWindowsArgs(
      displayName: row.displayName,
      windows: row.timeWindows,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
    );
    List<ParticipantWindowDraft>? result;
    if (_openWindowsEditor != null) {
      result = await _openWindowsEditor(args);
    } else if (!Get.testMode) {
      result = await Get.to<List<ParticipantWindowDraft>>(
        () => GroupShiftWindowsView(args: args),
      );
    }
    if (result != null) {
      draft.value = draft.value.setTimeWindows(row.participantId, result);
      errorMessage.value = null;
    }
  }

  /// Returns false when add was cancelled (hard cap or large-group dialog).
  Future<bool> addParticipant({
    required String participantId,
    required String displayName,
  }) async {
    if (draft.value.containsParticipant(participantId)) return false;
    final nextN = draft.value.length + 1;
    if (atHardCap(draft.value.length)) {
      errorMessage.value = 'Groups are limited to 32 participants';
      return false;
    }
    if (needsLargeGroupConfirm(nextN)) {
      final ok = await _askLargeGroupConfirm(nextN);
      if (!ok) return false;
    }
    final windows =
        isTimeBased
            ? defaultFullShiftWindows(shiftStart, shiftEnd)
            : const <ParticipantWindowDraft>[];
    draft.value = draft.value.add(
      GroupParticipantDraft(
        participantId: participantId,
        displayName: displayName,
        allocationValue: isTimeBased ? 0 : 0,
        isHostIncluded: participantId == args.shift.clientId,
        timeWindows: windows,
      ),
    );
    return true;
  }

  Future<bool> _askLargeGroupConfirm(int nextN) async {
    if (_confirmLargeGroup != null) return _confirmLargeGroup(nextN);
    if (Get.testMode) return true;
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Large group'),
        content: Text('Large group ($nextN). Continue?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> save() async {
    if (isSaving.value) return;
    errorMessage.value = null;
    final validation = draft.value.validate(
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
    );
    if (validation != null) {
      errorMessage.value = validation;
      return;
    }
    if (!isTimeBased &&
        !draft.value.equalSplit &&
        !sumsTo100(draft.value.participants.map((p) => p.allocationValue))) {
      errorMessage.value = remainingLabel;
      return;
    }

    isSaving.value = true;
    try {
      final timeBased = isTimeBased;
      final equal = !timeBased && draft.value.equalSplit;
      final updated = await _shifts.putParticipants(
        args.shift.id,
        ShiftParticipantsReplaceRequest(
          allocationStrategy:
              timeBased
                  ? GroupAllocationStrategy.timeBased
                  : GroupAllocationStrategy.percentage,
          equalSplit: equal,
          participants: [
            for (final p in draft.value.participants)
              if (timeBased)
                ShiftParticipantReplaceItem(
                  participantId: p.participantId,
                  allocationValue: 0,
                  timeWindows: [
                    for (final w in p.timeWindows)
                      ShiftParticipantTimeWindowInput(
                        participantStartTime: w.start,
                        participantEndTime: w.end,
                      ),
                  ],
                )
              else
                ShiftParticipantReplaceItem(
                  participantId: p.participantId,
                  allocationValue: equal ? null : p.allocationValue,
                ),
          ],
        ),
      );
      if (_onSaved != null) {
        _onSaved(updated);
      } else if (!Get.testMode) {
        Get.back(result: updated);
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) {
        AppToast.error('Could not save group', e.message);
      }
    } catch (e) {
      errorMessage.value = e.toString();
      if (!Get.testMode) {
        AppToast.error('Could not save group', e.toString());
      }
    } finally {
      isSaving.value = false;
    }
  }
}
