import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/views/shell/adaptive_navigation_shell.dart';
import 'package:rostiq/app/views/shell/responsive_scaffold.dart';

void main() {
  const destinations = [
    ResponsiveDestination(icon: Icons.home_outlined, label: 'Home'),
    ResponsiveDestination(icon: Icons.groups_outlined, label: 'Workforce'),
    ResponsiveDestination(icon: Icons.people_outline, label: 'Clients'),
    ResponsiveDestination(icon: Icons.event_available_outlined, label: 'Roster'),
    ResponsiveDestination(icon: Icons.payments_outlined, label: 'Payments'),
    ResponsiveDestination(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  testWidgets('narrow width uses bottom NavigationBar not rail', (tester) async {
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

  testWidgets('narrow width shows More when destinations exceed primary limit', (tester) async {
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

    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('wide width shows More on rail when destinations exceed rail primary limit', (tester) async {
    final many = List.generate(
      8,
      (i) => ResponsiveDestination(icon: Icons.circle, label: 'Item $i'),
    );
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigationShell(
          destinations: many,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const SizedBox(),
        ),
      ),
    );

    expect(find.text('More'), findsOneWidget);
  });
}
