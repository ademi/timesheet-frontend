import '../../jobs/data/models/job_models.dart';
import '../../shifts/data/models/shift_models.dart';

/// Composer surface preset (one engine; visibility differs).
enum ComposerPreset { oneSession, group }

/// Draft place alias — same XOR body as create / PATCH.
typedef DraftPlace = ShiftPlaceIn;

/// Single occurrence draft that drives One-session and Group presets.
class OccurrenceDraft {
  const OccurrenceDraft({
    required this.preset,
    this.shiftId,
    this.jobId,
    this.clientId,
    this.scheduledStart,
    this.scheduledEnd,
    this.place,
    this.participantIds = const [],
    this.equalSplit = true,
    this.allocationStrategy = 'percentage',
    this.workerCount = 1,
    this.requiredSlots = 1,
    this.supportItemCode,
    this.taskTemplate = const [],
    this.segmentTemplate = const [],
    this.contractorIds = const [],
    this.repeatEnabled = false,
    this.status = 'draft',
  });

  factory OccurrenceDraft.oneSession({
    String? clientId,
    DraftPlace? place,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? supportItemCode,
    List<TaskTemplateItem> taskTemplate = const [],
    bool repeatEnabled = false,
  }) {
    return OccurrenceDraft(
      preset: ComposerPreset.oneSession,
      clientId: clientId,
      participantIds: clientId != null ? [clientId] : const [],
      place: place,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      supportItemCode: supportItemCode,
      taskTemplate: taskTemplate,
      equalSplit: true,
      workerCount: 1,
      requiredSlots: 1,
      repeatEnabled: repeatEnabled,
    );
  }

  factory OccurrenceDraft.group({
    String? jobId,
    List<String> participantIds = const [],
    DraftPlace? place,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? supportItemCode,
    List<TaskTemplateItem> taskTemplate = const [],
    List<SegmentTemplateItem> segmentTemplate = const [],
    int workerCount = 1,
    int requiredSlots = 1,
    bool equalSplit = true,
  }) {
    return OccurrenceDraft(
      preset: ComposerPreset.group,
      jobId: jobId,
      participantIds: participantIds,
      place: place,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      supportItemCode: supportItemCode,
      taskTemplate: taskTemplate,
      segmentTemplate: segmentTemplate,
      equalSplit: equalSplit,
      workerCount: workerCount,
      requiredSlots: requiredSlots,
    );
  }

  final ComposerPreset preset;
  final String? shiftId;
  final String? jobId;
  final String? clientId;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DraftPlace? place;
  final List<String> participantIds;
  final bool equalSplit;
  final String allocationStrategy;
  final int workerCount;
  final int requiredSlots;
  final String? supportItemCode;
  final List<TaskTemplateItem> taskTemplate;
  final List<SegmentTemplateItem> segmentTemplate;
  final List<String> contractorIds;
  final bool repeatEnabled;
  final String status;

  /// One-session hides % / time-window allocation UI (implicit 100%).
  bool get showsAllocation => preset == ComposerPreset.group;

  /// Worker / open-slot controls are group-facing.
  bool get showsWorkerCount => preset == ComposerPreset.group;

  bool get hasSupportAnchor =>
      (supportItemCode != null && supportItemCode!.trim().isNotEmpty) ||
      segmentTemplate.any(
        (s) => s.anchorSupportItemCode.trim().isNotEmpty,
      );

  OccurrenceDraft copyWith({
    ComposerPreset? preset,
    String? shiftId,
    String? jobId,
    String? clientId,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    DraftPlace? place,
    List<String>? participantIds,
    bool? equalSplit,
    String? allocationStrategy,
    int? workerCount,
    int? requiredSlots,
    String? supportItemCode,
    List<TaskTemplateItem>? taskTemplate,
    List<SegmentTemplateItem>? segmentTemplate,
    List<String>? contractorIds,
    bool? repeatEnabled,
    String? status,
    bool clearPlace = false,
    bool clearSupportItemCode = false,
  }) {
    return OccurrenceDraft(
      preset: preset ?? this.preset,
      shiftId: shiftId ?? this.shiftId,
      jobId: jobId ?? this.jobId,
      clientId: clientId ?? this.clientId,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      place: clearPlace ? null : (place ?? this.place),
      participantIds: participantIds ?? this.participantIds,
      equalSplit: equalSplit ?? this.equalSplit,
      allocationStrategy: allocationStrategy ?? this.allocationStrategy,
      workerCount: workerCount ?? this.workerCount,
      requiredSlots: requiredSlots ?? this.requiredSlots,
      supportItemCode:
          clearSupportItemCode
              ? null
              : (supportItemCode ?? this.supportItemCode),
      taskTemplate: taskTemplate ?? this.taskTemplate,
      segmentTemplate: segmentTemplate ?? this.segmentTemplate,
      contractorIds: contractorIds ?? this.contractorIds,
      repeatEnabled: repeatEnabled ?? this.repeatEnabled,
      status: status ?? this.status,
    );
  }
}
