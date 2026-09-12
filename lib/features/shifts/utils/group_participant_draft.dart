import 'allocation_math.dart';
import 'participant_window_math.dart';

/// Group-level allocation mode (no mix across participants).
abstract final class GroupAllocationStrategy {
  static const percentage = 'percentage';
  static const timeBased = 'time_based';
}

/// One row in a group-shift participant draft (wizard / Edit group).
class GroupParticipantDraft {
  const GroupParticipantDraft({
    required this.participantId,
    required this.displayName,
    required this.allocationValue,
    this.isHostIncluded = false,
    this.timeWindows = const [],
  });

  final String participantId;
  final String displayName;
  final double allocationValue;

  /// True when this row is the host client included as a participant.
  final bool isHostIncluded;

  /// Local ISO windows when [GroupParticipantDraftSet.allocationStrategy]
  /// is [GroupAllocationStrategy.timeBased].
  final List<ParticipantWindowDraft> timeWindows;

  GroupParticipantDraft copyWith({
    String? participantId,
    String? displayName,
    double? allocationValue,
    bool? isHostIncluded,
    List<ParticipantWindowDraft>? timeWindows,
  }) {
    return GroupParticipantDraft(
      participantId: participantId ?? this.participantId,
      displayName: displayName ?? this.displayName,
      allocationValue: allocationValue ?? this.allocationValue,
      isHostIncluded: isHostIncluded ?? this.isHostIncluded,
      timeWindows: timeWindows ?? this.timeWindows,
    );
  }
}

/// Immutable draft set shared by Group Shift wizard and Edit group.
class GroupParticipantDraftSet {
  const GroupParticipantDraftSet({
    this.participants = const [],
    this.equalSplit = true,
    this.allocationStrategy = GroupAllocationStrategy.percentage,
  });

  final List<GroupParticipantDraft> participants;
  final bool equalSplit;
  final String allocationStrategy;

  bool get isTimeBased =>
      allocationStrategy == GroupAllocationStrategy.timeBased;

  int get length => participants.length;

  /// Returns an error message when invalid, otherwise `null`.
  ///
  /// For time-based mode pass [shiftStart]/[shiftEnd] (required for bounds).
  String? validate({DateTime? shiftStart, DateTime? shiftEnd}) {
    if (participants.isEmpty) {
      return 'Add at least one participant';
    }
    if (participants.length > 32) {
      return 'Groups are limited to 32 participants';
    }
    if (isTimeBased) {
      if (shiftStart == null || shiftEnd == null) {
        return 'Shift times are required for time windows';
      }
      for (final p in participants) {
        final err = validateParticipantWindows(
          p.timeWindows,
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
        );
        if (err != null) {
          return '${p.displayName}: $err';
        }
      }
      return null;
    }
    if (!equalSplit) {
      final values = participants.map((p) => p.allocationValue);
      if (!sumsTo100(values)) {
        return 'Allocations must sum to 100%';
      }
    }
    return null;
  }

  GroupParticipantDraftSet copyWith({
    List<GroupParticipantDraft>? participants,
    bool? equalSplit,
    String? allocationStrategy,
  }) {
    return GroupParticipantDraftSet(
      participants: participants ?? this.participants,
      equalSplit: equalSplit ?? this.equalSplit,
      allocationStrategy: allocationStrategy ?? this.allocationStrategy,
    );
  }

  GroupParticipantDraftSet add(GroupParticipantDraft participant) {
    var row = participant;
    if (isTimeBased && row.timeWindows.isEmpty) {
      // Caller should seed windows; leave empty so validate surfaces the issue
      // unless they already provided windows.
      row = participant;
    }
    final next = [...participants, row];
    if (!isTimeBased && equalSplit) {
      return copyWith(participants: _withEqualValues(next));
    }
    return copyWith(participants: List.unmodifiable(next));
  }

  GroupParticipantDraftSet remove(String participantId) {
    final next =
        participants.where((p) => p.participantId != participantId).toList();
    if (!isTimeBased && equalSplit) {
      return copyWith(participants: _withEqualValues(next));
    }
    return copyWith(participants: List.unmodifiable(next));
  }

  /// Enables equal split and redistributes to sum exactly 100%.
  GroupParticipantDraftSet recomputeEqualSplit() {
    return copyWith(
      equalSplit: true,
      allocationStrategy: GroupAllocationStrategy.percentage,
      participants: _withEqualValues(
        [
          for (final p in participants)
            p.copyWith(timeWindows: const []),
        ],
      ),
    );
  }

  /// Toggles equal-split mode. Enabling redistributes; disabling keeps values.
  /// No-op when time-based.
  GroupParticipantDraftSet withEqualSplit(bool enabled) {
    if (isTimeBased) return this;
    if (enabled) return recomputeEqualSplit();
    return copyWith(equalSplit: false);
  }

  /// Updates one row's Capacity % and forces manual (non-equal) percentage mode.
  GroupParticipantDraftSet setAllocation(
    String participantId,
    double allocationValue,
  ) {
    if (isTimeBased) return this;
    final next = [
      for (final p in participants)
        if (p.participantId == participantId)
          p.copyWith(allocationValue: allocationValue)
        else
          p,
    ];
    return copyWith(equalSplit: false, participants: List.unmodifiable(next));
  }

  /// Replaces local windows for one participant (window editor Done).
  GroupParticipantDraftSet setTimeWindows(
    String participantId,
    List<ParticipantWindowDraft> windows,
  ) {
    final next = [
      for (final p in participants)
        if (p.participantId == participantId)
          p.copyWith(
            timeWindows: List.unmodifiable(windows),
            allocationValue: 0,
          )
        else
          p,
    ];
    return copyWith(
      allocationStrategy: GroupAllocationStrategy.timeBased,
      equalSplit: false,
      participants: List.unmodifiable(next),
    );
  }

  /// Switches group strategy. → time seeds empty rows; → % clears windows + equal.
  GroupParticipantDraftSet withAllocationStrategy(
    String strategy, {
    required DateTime shiftStart,
    required DateTime shiftEnd,
  }) {
    if (strategy == GroupAllocationStrategy.timeBased) {
      final next = [
        for (final p in participants)
          p.copyWith(
            allocationValue: 0,
            timeWindows:
                p.timeWindows.isEmpty
                    ? defaultFullShiftWindows(shiftStart, shiftEnd)
                    : p.timeWindows,
          ),
      ];
      return copyWith(
        allocationStrategy: GroupAllocationStrategy.timeBased,
        equalSplit: false,
        participants: List.unmodifiable(next),
      );
    }
    return copyWith(
      allocationStrategy: GroupAllocationStrategy.percentage,
      equalSplit: true,
      participants: _withEqualValues([
        for (final p in participants) p.copyWith(timeWindows: const []),
      ]),
    );
  }

  double get remaining =>
      remainingTo100(participants.map((p) => p.allocationValue));

  bool containsParticipant(String participantId) =>
      participants.any((p) => p.participantId == participantId);

  static List<GroupParticipantDraft> _withEqualValues(
    List<GroupParticipantDraft> rows,
  ) {
    if (rows.isEmpty) {
      return const [];
    }
    final values = equalPercentageValues(rows.length);
    return List.unmodifiable([
      for (var i = 0; i < rows.length; i++)
        rows[i].copyWith(
          allocationValue: values[i],
          timeWindows: const [],
        ),
    ]);
  }
}
