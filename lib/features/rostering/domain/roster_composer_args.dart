import '../../clients/data/models/client_models.dart';
import '../../jobs/utils/unified_support_args.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../shifts/group_book/group_shift_book_args.dart';
import '../../shifts/group_book/group_shift_edit_controller.dart';
import 'occurrence_draft.dart';

/// Typed GetX route args for the unified rostering composer.
class RosterComposerArgs {
  const RosterComposerArgs({
    this.shiftId,
    this.shift,
    this.clientId,
    this.client,
    this.jobId,
    this.participantId,
    this.participantName,
    this.recurrenceRuleId,
    this.preset = ComposerPreset.oneSession,
    this.repeatEnabled = false,
  });

  final String? shiftId;
  final ShiftOut? shift;
  final String? clientId;
  final ClientOut? client;
  final String? jobId;
  final String? participantId;
  final String? participantName;
  final String? recurrenceRuleId;
  final ComposerPreset preset;
  final bool repeatEnabled;

  /// Parse GetX `arguments` from typed classes or legacy maps.
  factory RosterComposerArgs.fromRaw(Object? raw) {
    if (raw is RosterComposerArgs) return raw;
    if (raw is UnifiedSupportArgs) {
      return RosterComposerArgs.fromUnifiedSupport(raw);
    }
    if (raw is GroupShiftBookArgs) {
      return RosterComposerArgs.fromGroupBook(raw);
    }
    if (raw is GroupShiftEditArgs) {
      return RosterComposerArgs(
        shiftId: raw.shift.id,
        shift: raw.shift,
        jobId: raw.shift.jobId,
        preset: ComposerPreset.group,
      );
    }
    if (raw is ClientOut) {
      // Matches UnifiedSupportController: bare ClientOut → ongoing.
      return RosterComposerArgs(
        client: raw,
        clientId: raw.id,
        preset: ComposerPreset.oneSession,
        repeatEnabled: true,
      );
    }
    if (raw is Map) {
      return RosterComposerArgs.fromMap(Map<dynamic, dynamic>.from(raw));
    }
    return const RosterComposerArgs();
  }

  factory RosterComposerArgs.fromUnifiedSupport(UnifiedSupportArgs args) {
    final ongoing = args.initialMode == UnifiedSupportMode.ongoing;
    return RosterComposerArgs(
      client: args.client,
      clientId: args.clientId ?? args.client?.id,
      preset: ComposerPreset.oneSession,
      repeatEnabled: ongoing,
    );
  }

  factory RosterComposerArgs.fromGroupBook(GroupShiftBookArgs args) {
    return RosterComposerArgs(
      client: args.participant,
      clientId: args.participant?.id,
      participantId: args.participantId ?? args.participant?.id,
      participantName: args.participantName ?? args.participant?.fullName,
      preset: ComposerPreset.group,
    );
  }

  factory RosterComposerArgs.fromMap(Map<dynamic, dynamic> map) {
    final modeRaw = map['mode']?.toString() ?? map['initialMode']?.toString();
    final presetRaw = map['preset']?.toString();
    final repeatRaw = map['repeat'] ?? map['repeatEnabled'];

    var preset = ComposerPreset.oneSession;
    var repeatEnabled = false;

    if (presetRaw == 'group') {
      preset = ComposerPreset.group;
    } else if (modeRaw == 'group') {
      preset = ComposerPreset.group;
    } else if (modeRaw == 'ongoing') {
      preset = ComposerPreset.oneSession;
      repeatEnabled = true;
    } else if (modeRaw == 'one' || modeRaw == 'oneSession') {
      preset = ComposerPreset.oneSession;
      repeatEnabled = false;
    }

    if (repeatRaw == true ||
        repeatRaw?.toString() == 'true' ||
        map['ruleId'] != null ||
        map['rule_id'] != null ||
        map['recurrenceRuleId'] != null) {
      repeatEnabled = true;
    }

    final clientArg = map['client'];
    final ClientOut? client = clientArg is ClientOut ? clientArg : null;
    final shiftArg = map['shift'];
    final ShiftOut? shift = shiftArg is ShiftOut ? shiftArg : null;

    return RosterComposerArgs(
      shiftId:
          map['shiftId']?.toString() ??
          map['shift_id']?.toString() ??
          shift?.id,
      shift: shift,
      client: client,
      clientId:
          map['clientId']?.toString() ??
          map['client_id']?.toString() ??
          client?.id,
      jobId: map['jobId']?.toString() ?? map['job_id']?.toString(),
      participantId:
          map['participantId']?.toString() ??
          map['participant_id']?.toString(),
      participantName:
          map['participantName']?.toString() ??
          map['participant_name']?.toString(),
      recurrenceRuleId:
          map['recurrenceRuleId']?.toString() ??
          map['ruleId']?.toString() ??
          map['rule_id']?.toString(),
      preset: preset,
      repeatEnabled: repeatEnabled,
    );
  }
}
