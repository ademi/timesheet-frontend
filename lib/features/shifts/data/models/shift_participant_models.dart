// Shift participant DTOs for group-shift invoicing.

class ShiftParticipantAllocationWindow {
  const ShiftParticipantAllocationWindow({
    required this.participantStartTime,
    required this.participantEndTime,
  });

  final DateTime participantStartTime;
  final DateTime participantEndTime;

  Map<String, dynamic> toJson() => {
        'participant_start_time': participantStartTime.toUtc().toIso8601String(),
        'participant_end_time': participantEndTime.toUtc().toIso8601String(),
      };
}

class ShiftParticipantAllocationOut {
  const ShiftParticipantAllocationOut({
    required this.id,
    required this.shiftParticipantId,
    required this.participantStartTime,
    required this.participantEndTime,
    required this.createdAt,
  });

  final String id;
  final String shiftParticipantId;
  final DateTime participantStartTime;
  final DateTime participantEndTime;
  final DateTime createdAt;

  factory ShiftParticipantAllocationOut.fromJson(Map<String, dynamic> json) {
    return ShiftParticipantAllocationOut(
      id: json['id'].toString(),
      shiftParticipantId: json['shift_participant_id'].toString(),
      participantStartTime:
          DateTime.parse(json['participant_start_time'] as String),
      participantEndTime:
          DateTime.parse(json['participant_end_time'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ShiftParticipantOut {
  const ShiftParticipantOut({
    required this.id,
    required this.shiftId,
    required this.participantId,
    required this.allocationStrategy,
    required this.allocationValue,
    required this.status,
    this.timeWindows,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String shiftId;
  final String participantId;
  final String allocationStrategy; // percentage | time_based
  final double allocationValue;
  final String status; // active | removed
  final List<ShiftParticipantAllocationOut>? timeWindows;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == 'active';

  ShiftParticipantOut copyWith({
    List<ShiftParticipantAllocationOut>? timeWindows,
    double? allocationValue,
    String? status,
  }) {
    return ShiftParticipantOut(
      id: id,
      shiftId: shiftId,
      participantId: participantId,
      allocationStrategy: allocationStrategy,
      allocationValue: allocationValue ?? this.allocationValue,
      status: status ?? this.status,
      timeWindows: timeWindows ?? this.timeWindows,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ShiftParticipantOut.fromJson(Map<String, dynamic> json) {
    final windows = json['time_windows'];
    return ShiftParticipantOut(
      id: json['id'].toString(),
      shiftId: json['shift_id'].toString(),
      participantId: json['participant_id'].toString(),
      allocationStrategy: json['allocation_strategy'] as String? ?? 'percentage',
      allocationValue: (json['allocation_value'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'active',
      timeWindows: windows is List
          ? windows
              .whereType<Map>()
              .map(
                (e) => ShiftParticipantAllocationOut.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(growable: false)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ShiftParticipantCreateRequest {
  const ShiftParticipantCreateRequest({
    required this.participantId,
    required this.allocationStrategy,
    required this.allocationValue,
    required this.reason,
    this.timeWindows,
  });

  final String participantId;
  final String allocationStrategy;
  final double allocationValue;
  final String reason;
  final List<ShiftParticipantAllocationWindow>? timeWindows;

  Map<String, dynamic> toJson() => {
        'participant_id': participantId,
        'allocation_strategy': allocationStrategy,
        'allocation_value': allocationValue,
        'reason': reason,
        if (timeWindows != null)
          'time_windows': timeWindows!.map((w) => w.toJson()).toList(),
      };
}

class ShiftParticipantAllocationUpdateRequest {
  const ShiftParticipantAllocationUpdateRequest({
    required this.allocationValue,
    required this.reason,
  });

  final double allocationValue;
  final String reason;

  Map<String, dynamic> toJson() => {
        'allocation_value': allocationValue,
        'reason': reason,
      };
}

class AllocationChangeLogOut {
  const AllocationChangeLogOut({
    required this.id,
    required this.shiftId,
    required this.changeType,
    required this.participantId,
    this.oldAllocationValue,
    this.newAllocationValue,
    this.oldAllocationStrategy,
    this.newAllocationStrategy,
    required this.changeReason,
    this.changedByUserId,
    required this.createdAt,
  });

  final String id;
  final String shiftId;
  final String changeType;
  final String participantId;
  final double? oldAllocationValue;
  final double? newAllocationValue;
  final String? oldAllocationStrategy;
  final String? newAllocationStrategy;
  final String changeReason;
  final String? changedByUserId;
  final DateTime createdAt;

  factory AllocationChangeLogOut.fromJson(Map<String, dynamic> json) {
    return AllocationChangeLogOut(
      id: json['id'].toString(),
      shiftId: json['shift_id'].toString(),
      changeType: json['change_type'] as String? ?? '',
      participantId: json['participant_id'].toString(),
      oldAllocationValue:
          (json['old_allocation_value'] as num?)?.toDouble(),
      newAllocationValue:
          (json['new_allocation_value'] as num?)?.toDouble(),
      oldAllocationStrategy: json['old_allocation_strategy'] as String?,
      newAllocationStrategy: json['new_allocation_strategy'] as String?,
      changeReason: json['change_reason'] as String? ?? '',
      changedByUserId: json['changed_by_user_id']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
