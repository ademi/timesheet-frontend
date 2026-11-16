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
      steps: ['Open Roster', 'Publish when ready'],
      tags: ['roster', 'publish'],
      routeHints: [AppRoutes.staffVisits, AppRoutes.staffRosterCompose],
    );

    test('matchesRoute for hint and nested paths', () {
      expect(guide.matchesRoute(AppRoutes.staffVisits), isTrue);
      expect(guide.matchesRoute('${AppRoutes.staffVisits}/detail'), isTrue);
      expect(guide.matchesRoute(AppRoutes.staffRosterCompose), isTrue);
      expect(guide.matchesRoute(AppRoutes.staffHome), isFalse);
    });

    test('matchesQuery across title, tags, and steps', () {
      expect(guide.matchesQuery('publish'), isTrue);
      expect(guide.matchesQuery('ROSTER'), isTrue);
      expect(guide.matchesQuery('Open Roster'), isTrue);
      expect(guide.matchesQuery('xyz-nope'), isFalse);
      expect(guide.matchesQuery(''), isTrue);
    });
  });

  group('TutorialCatalog', () {
    test('ships starter guides with route hints', () {
      expect(TutorialCatalog.guides.length, greaterThanOrEqualTo(6));
      expect(TutorialCatalog.byId('roster-publish'), isNotNull);
      expect(
        TutorialCatalog.byId('roster-publish')!.matchesRoute(AppRoutes.staffVisits),
        isTrue,
      );
    });
  });
}
