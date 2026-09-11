import 'allocation_math.dart';

/// One row in a group-shift participant draft (wizard / Edit group).
class GroupParticipantDraft {
  const GroupParticipantDraft({
    required this.participantId,
    required this.displayName,
    required this.allocationValue,
    this.isHostIncluded = false,
  });

  final String participantId;
  final String displayName;
  final double allocationValue;

  /// True when this row is the host client included as a participant.
  final bool isHostIncluded;

  GroupParticipantDraft copyWith({
    String? participantId,
    String? displayName,
    double? allocationValue,
    bool? isHostIncluded,
  }) {
    return GroupParticipantDraft(
      participantId: participantId ?? this.participantId,
      displayName: displayName ?? this.displayName,
      allocationValue: allocationValue ?? this.allocationValue,
      isHostIncluded: isHostIncluded ?? this.isHostIncluded,
    );
  }
}

/// Immutable draft set shared by Group Shift wizard and Edit group.
class GroupParticipantDraftSet {
  const GroupParticipantDraftSet({
    this.participants = const [],
    this.equalSplit = true,
  });

  final List<GroupParticipantDraft> participants;
  final bool equalSplit;

  int get length => participants.length;

  /// Returns an error message when invalid, otherwise `null`.
  String? validate() {
    if (participants.isEmpty) {
      return 'Add at least one participant';
    }
    if (participants.length > 32) {
      return 'Groups are limited to 32 participants';
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
  }) {
    return GroupParticipantDraftSet(
      participants: participants ?? this.participants,
      equalSplit: equalSplit ?? this.equalSplit,
    );
  }

  GroupParticipantDraftSet add(GroupParticipantDraft participant) {
    final next = [...participants, participant];
    if (equalSplit) {
      return copyWith(participants: _withEqualValues(next));
    }
    return copyWith(participants: List.unmodifiable(next));
  }

  GroupParticipantDraftSet remove(String participantId) {
    final next =
        participants.where((p) => p.participantId != participantId).toList();
    if (equalSplit) {
      return copyWith(participants: _withEqualValues(next));
    }
    return copyWith(participants: List.unmodifiable(next));
  }

  /// Enables equal split and redistributes to sum exactly 100%.
  GroupParticipantDraftSet recomputeEqualSplit() {
    return copyWith(
      equalSplit: true,
      participants: _withEqualValues(participants),
    );
  }

  /// Toggles equal-split mode. Enabling redistributes; disabling keeps values.
  GroupParticipantDraftSet withEqualSplit(bool enabled) {
    if (enabled) return recomputeEqualSplit();
    return copyWith(equalSplit: false);
  }

  /// Updates one row's Capacity % and forces manual (non-equal) mode.
  GroupParticipantDraftSet setAllocation(
    String participantId,
    double allocationValue,
  ) {
    final next = [
      for (final p in participants)
        if (p.participantId == participantId)
          p.copyWith(allocationValue: allocationValue)
        else
          p,
    ];
    return copyWith(equalSplit: false, participants: List.unmodifiable(next));
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
        rows[i].copyWith(allocationValue: values[i]),
    ]);
  }
}
