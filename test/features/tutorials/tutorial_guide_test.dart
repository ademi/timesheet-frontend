import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/features/tutorials/data/tutorial_catalog.dart';
import 'package:rostiq/features/tutorials/models/tutorial_guide.dart';

void main() {
  group('TutorialGuide', () {
    const guide = TutorialGuide(
      id: 'roster',
      title: 'Building and publishing a roster week',
      summary: 'Compose and publish visits',
      tags: ['roster', 'publish'],
      routeHints: [AppRoutes.staffVisits, AppRoutes.staffRosterCompose],
      sections: [
        TutorialSection(
          id: 'board',
          heading: 'The roster board',
          body: 'Week board for participants and workers.',
          steps: ['Open Roster', 'Scan the week'],
        ),
        TutorialSection(
          id: 'publish',
          heading: 'Publishing the week',
          steps: ['Publish when ready'],
        ),
      ],
    );

    test('matchesRoute for hint and nested paths', () {
      expect(guide.matchesRoute(AppRoutes.staffVisits), isTrue);
      expect(guide.matchesRoute('${AppRoutes.staffVisits}/detail'), isTrue);
      expect(guide.matchesRoute(AppRoutes.staffRosterCompose), isTrue);
      expect(guide.matchesRoute(AppRoutes.staffHome), isFalse);
    });

    test('matchesQuery across title, sections, and steps', () {
      expect(guide.matchesQuery('publish'), isTrue);
      expect(guide.matchesQuery('ROSTER'), isTrue);
      expect(guide.matchesQuery('Open Roster'), isTrue);
      expect(guide.matchesQuery('week board'), isTrue);
      expect(guide.matchesQuery('xyz-nope'), isFalse);
      expect(guide.matchesQuery(''), isTrue);
    });
  });

  group('TutorialCatalog', () {
    test('ships article-style guides with sections and steps', () {
      expect(TutorialCatalog.guides.length, greaterThanOrEqualTo(6));
      final roster = TutorialCatalog.byId('roster-publish');
      expect(roster, isNotNull);
      expect(roster!.sections, isNotEmpty);
      expect(
        roster.sections.any((s) => s.steps.isNotEmpty),
        isTrue,
      );
      expect(roster.matchesRoute(AppRoutes.staffVisits), isTrue);
    });
  });
}
