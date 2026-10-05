import '../../domain/occurrence_draft.dart';

/// One-session vs Group field visibility (single engine; visibility differs).
abstract final class PresetVisibility {
  PresetVisibility._();

  static bool showsAllocation(ComposerPreset preset) =>
      preset == ComposerPreset.group;

  static bool showsWorkerCount(ComposerPreset preset) =>
      preset == ComposerPreset.group;

  static bool showsParticipantPicker(ComposerPreset preset) => true;

  static bool hidesAllocationFor(OccurrenceDraft draft) => !draft.showsAllocation;
}
