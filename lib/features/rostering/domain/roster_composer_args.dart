import '../../clients/data/models/client_models.dart';
import '../../jobs/utils/unified_support_args.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../shifts/group_book/group_shift_book_args.dart';
import '../../shifts/group_book/group_shift_edit_args.dart';
import '../data/composer_models.dart';
import 'occurrence_draft.dart';

/// Optional scroll/menu focus when opening the composer from a legacy route.
enum ComposerFocusSection { plan, people, publish }

/// Typed GetX route args for the unified rostering composer.
class RosterComposerArgs {
  const RosterComposerArgs({
    this.shiftId,
    this.shift,
    this.composerSeed,
    this.clientId,
    this.client,
    this.jobId,
    this.participantId,
    this.participantName,
    this.recurrenceRuleId,
    this.preset = ComposerPreset.oneSession,
    this.repeatEnabled = false,
    this.focusSection = ComposerFocusSection.plan,
  });

  final String? shiftId;
  final ShiftOut? shift;

  /// Full composer aggregate from copy / prior hydrate — skips `GET …/composer`.
  final ComposerShiftOut? composerSeed;
  final String? clientId;
  final ClientOut? client;
  final String? jobId;
  final String? participantId;
  final String? participantName;
  final String? recurrenceRuleId;
  final ComposerPreset preset;
  final bool repeatEnabled;
  final ComposerFocusSection focusSection;

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
        focusSection: ComposerFocusSection.people,
      );
    }
    if (raw is ShiftOut) {
      return RosterComposerArgs(
        shiftId: raw.id,
        shift: raw,
        jobId: raw.jobId,
        clientId: raw.clientId,
        preset:
            raw.participants.length > 1
                ? ComposerPreset.group
                : ComposerPreset.oneSession,
      );
    }
    if (raw is ClientOut) {
      // Legacy Unified Support: bare ClientOut → ongoing / Repeat on.
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

  /// Resolve composer args from navigation [raw] plus URL query/path [params].
  ///
  /// On web refresh GoRouter `extra` is null; query still carries `clientId`,
  /// `id` / `shiftId`, `mode`, etc. Typed [raw] wins for set fields; params fill
  /// gaps. When [raw] yields empty defaults, params also drive preset/repeat/focus.
  factory RosterComposerArgs.fromRawAndParams(
    Object? raw, {
    Map<String, String?> params = const {},
  }) {
    final base = RosterComposerArgs.fromRaw(raw);
    final overlay = <dynamic, dynamic>{};
    void put(String key, String? value) {
      if (value != null && value.isNotEmpty) overlay[key] = value;
    }

    put(
      'shiftId',
      params['shiftId'] ?? params['id'] ?? params['shift_id'],
    );
    put('clientId', params['clientId'] ?? params['client_id']);
    put('jobId', params['jobId'] ?? params['job_id']);
    put('mode', params['mode']);
    put('preset', params['preset']);
    put('focus', params['focus'] ?? params['focusSection']);
    put(
      'participantId',
      params['participantId'] ?? params['participant_id'],
    );
    put(
      'participantName',
      params['participantName'] ?? params['participant_name'],
    );
    put(
      'ruleId',
      params['ruleId'] ?? params['rule_id'] ?? params['recurrenceRuleId'],
    );
    put('repeat', params['repeat']);

    if (overlay.isEmpty) return base;

    final fromParams = RosterComposerArgs.fromMap(overlay);
    final baseIsEmpty =
        base.shiftId == null &&
        base.clientId == null &&
        base.jobId == null &&
        base.shift == null &&
        base.client == null &&
        base.composerSeed == null &&
        base.participantId == null &&
        base.recurrenceRuleId == null;

    return base.copyWith(
      shiftId: base.shiftId ?? fromParams.shiftId,
      clientId: base.clientId ?? fromParams.clientId,
      jobId: base.jobId ?? fromParams.jobId,
      participantId: base.participantId ?? fromParams.participantId,
      participantName: base.participantName ?? fromParams.participantName,
      recurrenceRuleId: base.recurrenceRuleId ?? fromParams.recurrenceRuleId,
      preset: baseIsEmpty ? fromParams.preset : base.preset,
      repeatEnabled: baseIsEmpty ? fromParams.repeatEnabled : base.repeatEnabled,
      focusSection: baseIsEmpty ? fromParams.focusSection : base.focusSection,
    );
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
    final seedArg = map['composerSeed'] ?? map['composer_seed'];
    final ComposerShiftOut? composerSeed =
        seedArg is ComposerShiftOut ? seedArg : null;

    final focusRaw = map['focus']?.toString() ?? map['focusSection']?.toString();
    var focus = ComposerFocusSection.plan;
    if (focusRaw == 'people') {
      focus = ComposerFocusSection.people;
    } else if (focusRaw == 'publish') {
      focus = ComposerFocusSection.publish;
    }

    return RosterComposerArgs(
      shiftId:
          map['shiftId']?.toString() ??
          map['shift_id']?.toString() ??
          composerSeed?.shift.id ??
          shift?.id,
      shift: shift ?? composerSeed?.shift,
      composerSeed: composerSeed,
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
      focusSection: focus,
    );
  }

  RosterComposerArgs copyWith({
    String? shiftId,
    ShiftOut? shift,
    ComposerShiftOut? composerSeed,
    String? clientId,
    ClientOut? client,
    String? jobId,
    String? participantId,
    String? participantName,
    String? recurrenceRuleId,
    ComposerPreset? preset,
    bool? repeatEnabled,
    ComposerFocusSection? focusSection,
  }) {
    return RosterComposerArgs(
      shiftId: shiftId ?? this.shiftId,
      shift: shift ?? this.shift,
      composerSeed: composerSeed ?? this.composerSeed,
      clientId: clientId ?? this.clientId,
      client: client ?? this.client,
      jobId: jobId ?? this.jobId,
      participantId: participantId ?? this.participantId,
      participantName: participantName ?? this.participantName,
      recurrenceRuleId: recurrenceRuleId ?? this.recurrenceRuleId,
      preset: preset ?? this.preset,
      repeatEnabled: repeatEnabled ?? this.repeatEnabled,
      focusSection: focusSection ?? this.focusSection,
    );
  }
}
