import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/views/shell/adaptive_navigation_shell.dart';
import 'package:rostiq/app/views/shell/responsive_scaffold.dart';

void main() {
  const destinations = [
    ResponsiveDestination(icon: Icons.home_outlined, label: 'Home'),
    ResponsiveDestination(
      icon: Icons.event_available_outlined,
      label: 'Roster',
    ),
    ResponsiveDestination(icon: Icons.people_outline, label: 'Clients'),
    ResponsiveDestination(icon: Icons.groups_outlined, label: 'Workforce'),
    ResponsiveDestination(icon: Icons.payments_outlined, label: 'Payments'),
    ResponsiveDestination(icon: Icons.receipt_long_outlined, label: 'Billing'),
    ResponsiveDestination(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  testWidgets('narrow width uses bottom NavigationBar not rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const Text('Body'),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('wide width uses left NavigationRail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const Text('Body'),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('narrow width pins first four and shows More for overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const SizedBox(),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Roster'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
    expect(find.text('Workforce'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    // Overflow labels are not on the bar until More opens.
    expect(find.text('Payments'), findsNothing);
    expect(find.text('Billing'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('narrow More sheet lists overflow destinations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);

    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (i) => selected = i,
          child: const SizedBox(),
        ),
      ),
    );

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(selected, destinations.indexWhere((d) => d.label == 'Settings'));
  });

  testWidgets('wide width shows every destination without More', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const SizedBox(),
        ),
      ),
    );

    expect(find.text('More'), findsNothing);
    for (final destination in destinations) {
      expect(find.text(destination.label), findsOneWidget);
    }
  });

  testWidgets('narrow with ≤4 destinations does not show More', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);

    const few = [
      ResponsiveDestination(icon: Icons.home_outlined, label: 'Home'),
      ResponsiveDestination(icon: Icons.settings_outlined, label: 'Settings'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: few,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const SizedBox(),
        ),
      ),
    );

    expect(find.text('More'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
