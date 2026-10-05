import 'package:flutter/widgets.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../clients/data/models/client_models.dart';
import '../../../jobs/utils/unified_support_args.dart';
import '../../../shifts/data/models/shift_models.dart';
import '../../../shifts/group_book/group_shift_book_args.dart';
import '../../../shifts/group_book/group_shift_edit_args.dart';
import '../../domain/occurrence_draft.dart';
import '../../domain/roster_composer_args.dart';

/// Soft-cutover redirect matrix (P0-6 / L1). Pure mapping for tests + middleware.
abstract final class ComposerCutover {
  ComposerCutover._();

  /// Canonical composer route.
  static const composeRoute = AppRoutes.staffRosterCompose;

  /// Legacy routes that redirect into the composer (travel is intentionally absent).
  static const redirectedLegacyRoutes = <String>{
    AppRoutes.staffUnifiedSupport,
    AppRoutes.staffOngoingSupport,
    AppRoutes.staffRecurrenceRuleForm,
    AppRoutes.staffGroupShiftBook,
    AppRoutes.staffGroupShiftEdit,
    AppRoutes.staffGroupShiftWindows,
    AppRoutes.staffGroupShiftRemove,
    AppRoutes.staffGroupShiftPublish,
  };

  static ShiftOut? extractShift(Object? raw) {
    if (raw is ShiftOut) return raw;
    if (raw is GroupShiftEditArgs) return raw.shift;
    if (raw is RosterComposerArgs) return raw.shift;
    if (raw is Map) {
      final shift = raw['shift'];
      if (shift is ShiftOut) return shift;
    }
    return null;
  }

  static bool isDraftShift(ShiftOut? shift) =>
      shift == null || shift.status == 'draft';

  /// Resolve legacy route → composer or shift detail (published bounce).
  ///
  /// [contextualJobId] covers `staffRecurrenceRuleForm` when job lives on
  /// [JobsController.selected] rather than route args.
  static RouteSettings resolve({
    required String legacyRoute,
    Object? arguments,
    String? contextualJobId,
  }) {
    switch (legacyRoute) {
      case AppRoutes.staffUnifiedSupport:
        return RouteSettings(
          name: composeRoute,
          arguments: RosterComposerArgs.fromRaw(arguments),
        );

      case AppRoutes.staffOngoingSupport:
        return RouteSettings(
          name: composeRoute,
          arguments: _ongoingArgs(arguments),
        );

      case AppRoutes.staffRecurrenceRuleForm:
        return RouteSettings(
          name: composeRoute,
          arguments: _recurrenceArgs(arguments, contextualJobId),
        );

      case AppRoutes.staffGroupShiftBook:
        return RouteSettings(
          name: composeRoute,
          arguments: RosterComposerArgs.fromRaw(
            arguments is GroupShiftBookArgs || arguments is Map
                ? arguments
                : const GroupShiftBookArgs(),
          ),
        );

      case AppRoutes.staffGroupShiftEdit:
        return _draftOrDetail(
          arguments,
          focus: ComposerFocusSection.people,
        );

      case AppRoutes.staffGroupShiftWindows:
      case AppRoutes.staffGroupShiftRemove:
        return _draftOrDetail(
          arguments,
          focus: ComposerFocusSection.people,
        );

      case AppRoutes.staffGroupShiftPublish:
        return _draftOrDetail(
          arguments,
          focus: ComposerFocusSection.publish,
        );

      default:
        return RouteSettings(name: legacyRoute, arguments: arguments);
    }
  }

  static RosterComposerArgs _ongoingArgs(Object? arguments) {
    if (arguments is RosterComposerArgs) {
      return arguments.copyWith(
        preset: ComposerPreset.oneSession,
        repeatEnabled: true,
      );
    }
    if (arguments is UnifiedSupportArgs) {
      return RosterComposerArgs.fromUnifiedSupport(
        UnifiedSupportArgs(
          client: arguments.client,
          clientId: arguments.clientId,
          initialMode: UnifiedSupportMode.ongoing,
        ),
      );
    }
    if (arguments is ClientOut) {
      return RosterComposerArgs(
        client: arguments,
        clientId: arguments.id,
        preset: ComposerPreset.oneSession,
        repeatEnabled: true,
      );
    }
    if (arguments is Map) {
      return RosterComposerArgs.fromMap(
        Map<dynamic, dynamic>.from(arguments),
      ).copyWith(preset: ComposerPreset.oneSession, repeatEnabled: true);
    }
    return const RosterComposerArgs(
      preset: ComposerPreset.oneSession,
      repeatEnabled: true,
    );
  }

  static RosterComposerArgs _recurrenceArgs(
    Object? arguments,
    String? contextualJobId,
  ) {
    final base = RosterComposerArgs.fromRaw(arguments);
    final jobId = base.jobId ?? contextualJobId;
    return base.copyWith(
      jobId: jobId,
      repeatEnabled: true,
      preset: base.preset,
    );
  }

  static RouteSettings _draftOrDetail(
    Object? arguments, {
    required ComposerFocusSection focus,
  }) {
    final shift = extractShift(arguments);
    if (shift != null && !isDraftShift(shift)) {
      return RouteSettings(
        name: AppRoutes.staffShiftDetail,
        arguments: shift,
      );
    }
    final mapped = RosterComposerArgs.fromRaw(arguments).copyWith(
      focusSection: focus,
      preset: ComposerPreset.group,
    );
    return RouteSettings(name: composeRoute, arguments: mapped);
  }
}
