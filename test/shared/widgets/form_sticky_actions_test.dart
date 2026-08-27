import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/themes/app_colors.dart';
import 'package:rostiq/shared/widgets/form_sticky_actions.dart';

void main() {
  testWidgets(
    'Cancel outlined + primary elevated, each Expanded, min height 48, AppColors.primary',
    (tester) async {
      var cancelled = false;
      var saved = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormStickyActions(
              onCancel: () => cancelled = true,
              primaryLabel: 'Save',
              onPrimary: () => saved = true,
            ),
          ),
        ),
      );

      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);

      expect(
        find.ancestor(
          of: find.widgetWithText(OutlinedButton, 'Cancel'),
          matching: find.byType(Expanded),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.widgetWithText(ElevatedButton, 'Save'),
          matching: find.byType(Expanded),
        ),
        findsOneWidget,
      );

      final cancel = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Cancel'),
      );
      final primary = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save'),
      );
      expect(cancel.style?.minimumSize?.resolve({})?.height, 48);
      expect(primary.style?.minimumSize?.resolve({})?.height, 48);
      expect(primary.style?.backgroundColor?.resolve({}), AppColors.primary);
      expect(primary.style?.foregroundColor?.resolve({}), AppColors.onPrimary);

      await tester.tap(find.text('Cancel'));
      await tester.tap(find.text('Save'));
      expect(cancelled, isTrue);
      expect(saved, isTrue);
    },
  );

  testWidgets('optional secondary is Expanded with min height 48', (
    tester,
  ) async {
    var drafted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormStickyActions(
            onCancel: () {},
            secondaryLabel: 'Save draft',
            onSecondary: () => drafted = true,
            primaryLabel: 'Activate',
            onPrimary: () {},
          ),
        ),
      ),
    );

    expect(find.widgetWithText(OutlinedButton, 'Save draft'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.widgetWithText(OutlinedButton, 'Save draft'),
        matching: find.byType(Expanded),
      ),
      findsOneWidget,
    );

    final secondary = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Save draft'),
    );
    expect(secondary.style?.minimumSize?.resolve({})?.height, 48);

    await tester.tap(find.text('Save draft'));
    expect(drafted, isTrue);
  });

  testWidgets('primary is disabled when onPrimary is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FormStickyActions(
            onCancel: _noop,
            primaryLabel: 'Activate',
            onPrimary: null,
          ),
        ),
      ),
    );

    final primary = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Activate'),
    );
    expect(primary.onPressed, isNull);
  });
}

void _noop() {}
