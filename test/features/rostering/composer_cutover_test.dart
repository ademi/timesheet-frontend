import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/jobs/utils/unified_support_args.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/rostering/presentation/redirects/composer_cutover.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/group_book/group_shift_book_args.dart';

ClientOut _client(String id) => ClientOut(
  id: id,
  tenantId: 't1',
  fullName: 'Alex',
  status: 'active',
  metadata: const {},
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

ShiftOut _shift(String id, {String status = 'draft'}) => ShiftOut(
  id: id,
  tenantId: 't1',
  jobId: 'job-1',
  jobTitle: 'Support',
  scheduledStart: DateTime.utc(2026, 10, 4, 9),
  scheduledEnd: DateTime.utc(2026, 10, 4, 12),
  requiredSlots: 1,
  openSlots: 1,
  status: status,
  createdAt: DateTime.utc(2026, 10, 4),
  updatedAt: DateTime.utc(2026, 10, 4),
);

void main() {
  group('ComposerCutover redirect matrix', () {
    test('staffUnifiedSupport → composer with UnifiedSupportArgs mapping', () {
      final client = _client('c1');
      final settings = ComposerCutover.resolve(
        legacyRoute: AppRoutes.staffUnifiedSupport,
        arguments: UnifiedSupportArgs.forClient(
          client,
          mode: UnifiedSupportMode.oneSession,
        ),
      );
      expect(settings.name, AppRoutes.staffRosterCompose);
      final args = settings.arguments as RosterComposerArgs;
      expect(args.clientId, 'c1');
      expect(args.preset, ComposerPreset.oneSession);
      expect(args.repeatEnabled, isFalse);
    });

    test('staffOngoingSupport → composer one-session + Repeat on', () {
      final settings = ComposerCutover.resolve(
        legacyRoute: AppRoutes.staffOngoingSupport,
        arguments: _client('c2'),
      );
      expect(settings.name, AppRoutes.staffRosterCompose);
      final args = settings.arguments as RosterComposerArgs;
      expect(args.preset, ComposerPreset.oneSession);
      expect(args.repeatEnabled, isTrue);
      expect(args.clientId, 'c2');
    });

    test('staffRecurrenceRuleForm → composer jobId + Repeat on', () {
      final settings = ComposerCutover.resolve(
        legacyRoute: AppRoutes.staffRecurrenceRuleForm,
        arguments: null,
        contextualJobId: 'job-99',
      );
      expect(settings.name, AppRoutes.staffRosterCompose);
      final args = settings.arguments as RosterComposerArgs;
      expect(args.jobId, 'job-99');
      expect(args.repeatEnabled, isTrue);
    });

    test('staffGroupShiftBook → composer group', () {
      final settings = ComposerCutover.resolve(
        legacyRoute: AppRoutes.staffGroupShiftBook,
        arguments: const GroupShiftBookArgs(participantId: 'p1'),
      );
      expect(settings.name, AppRoutes.staffRosterCompose);
      final args = settings.arguments as RosterComposerArgs;
      expect(args.preset, ComposerPreset.group);
      expect(args.participantId, 'p1');
    });

    test('staffGroupShiftEdit draft → composer; published → detail', () {
      final draft = ComposerCutover.resolve(
        legacyRoute: AppRoutes.staffGroupShiftEdit,
        arguments: _shift('s-draft'),
      );
      expect(draft.name, AppRoutes.staffRosterCompose);
      expect(
        (draft.arguments as RosterComposerArgs).focusSection,
        ComposerFocusSection.people,
      );

      final published = ComposerCutover.resolve(
        legacyRoute: AppRoutes.staffGroupShiftEdit,
        arguments: _shift('s-pub', status: 'published'),
      );
      expect(published.name, AppRoutes.staffShiftDetail);
      expect((published.arguments as ShiftOut).id, 's-pub');
    });

    test('staffGroupShiftWindows/Remove draft → people; published → detail', () {
      for (final route in [
        AppRoutes.staffGroupShiftWindows,
        AppRoutes.staffGroupShiftRemove,
      ]) {
        final draft = ComposerCutover.resolve(
          legacyRoute: route,
          arguments: {'shift': _shift('s1')},
        );
        expect(draft.name, AppRoutes.staffRosterCompose);
        expect(
          (draft.arguments as RosterComposerArgs).focusSection,
          ComposerFocusSection.people,
        );

        final published = ComposerCutover.resolve(
          legacyRoute: route,
          arguments: _shift('s2', status: 'published'),
        );
        expect(published.name, AppRoutes.staffShiftDetail);
      }
    });

    test('staffGroupShiftPublish draft → publish focus; published → detail', () {
      final draft = ComposerCutover.resolve(
        legacyRoute: AppRoutes.staffGroupShiftPublish,
        arguments: _shift('s3'),
      );
      expect(draft.name, AppRoutes.staffRosterCompose);
      expect(
        (draft.arguments as RosterComposerArgs).focusSection,
        ComposerFocusSection.publish,
      );

      final published = ComposerCutover.resolve(
        legacyRoute: AppRoutes.staffGroupShiftPublish,
        arguments: _shift('s4', status: 'published'),
      );
      expect(published.name, AppRoutes.staffShiftDetail);
    });

    test('staffGroupShiftTravel is not in redirected set', () {
      expect(
        ComposerCutover.redirectedLegacyRoutes.contains(
          AppRoutes.staffGroupShiftTravel,
        ),
        isFalse,
      );
    });
  });
}
