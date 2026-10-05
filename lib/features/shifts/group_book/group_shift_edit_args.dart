import '../data/models/shift_models.dart';

/// Legacy route args for [AppRoutes.staffGroupShiftEdit] (soft-cutover source).
///
/// Kept so redirects / [RosterComposerArgs.fromRaw] still accept typed args
/// from deep links or stale call sites. The edit wizard itself is removed.
class GroupShiftEditArgs {
  const GroupShiftEditArgs({required this.shift});

  final ShiftOut shift;
}
