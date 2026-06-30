import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_gate_attendance_app/app/routes/app_routes.dart';
import 'package:yemen_gate_attendance_app/app/views/shell/admin_shell_routes.dart';
import 'package:yemen_gate_attendance_app/app/views/shell/responsive_scaffold.dart';
import 'package:yemen_gate_attendance_app/app/views/shell/two_pane.dart';
import 'package:yemen_gate_attendance_app/core/responsive/adaptive_grid.dart';
import 'package:yemen_gate_attendance_app/core/responsive/breakpoints.dart';
import 'package:yemen_gate_attendance_app/core/responsive/max_width_box.dart';

void main() {
  group('Phase 7 — breakpoint matrix', () {
    test('7.1 phone 360dp classifies as phone', () {
      expect(Breakpoints.classify(360), DeviceClass.phone);
      expect(useTwoPaneLayout(360), isFalse);
    });

    test('7.2 phone 390dp classifies as phone (design baseline width)', () {
      expect(Breakpoints.classify(390), DeviceClass.phone);
    });

    test('7.3 phone 430dp classifies as phone without desktop layout', () {
      expect(Breakpoints.classify(430), DeviceClass.phone);
      expect(useTwoPaneLayout(430), isFalse);
    });

    test('7.4 tablet portrait 800dp uses tablet grid, no rail/two-pane', () {
      expect(Breakpoints.classify(800), DeviceClass.tablet);
      expect(useTwoPaneLayout(800), isFalse);
    });

    test('7.5 web 1280px enables desktop class, rail, and two-pane', () {
      expect(Breakpoints.classify(1280), DeviceClass.desktop);
      expect(useTwoPaneLayout(1280), isTrue);
    });

    test('7.6 web 1920px stays desktop; content caps at maxContent', () {
      expect(Breakpoints.classify(1920), DeviceClass.desktop);
      expect(Breakpoints.maxContent, 1200);
      expect(Breakpoints.formMaxWidth, 480);
    });
  });

  group('Phase 7 — layout widgets', () {
    testWidgets('MaxWidthBox caps page content at maxContent (7.6)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(tester.view.resetPhysicalSize);

      late BoxConstraints captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: MaxWidthBox(
              maxWidth: Breakpoints.maxContent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  captured = constraints;
                  return const SizedBox(height: 40);
                },
              ),
            ),
          ),
        ),
      );

      expect(captured.maxWidth, Breakpoints.maxContent);
    });

    testWidgets('MaxWidthBox caps forms at formMaxWidth (7.6)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(tester.view.resetPhysicalSize);

      late BoxConstraints captured;
      await tester.pumpWidget(
        MaterialApp(
          home: MaxWidthBox(
            maxWidth: Breakpoints.formMaxWidth,
            child: LayoutBuilder(
              builder: (context, constraints) {
                captured = constraints;
                return const SizedBox(height: 40);
              },
            ),
          ),
        ),
      );

      expect(captured.maxWidth, Breakpoints.formMaxWidth);
    });

    testWidgets('ResponsiveScaffold shows rail at 1280px (7.5)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveScaffold(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: AdminShellRoutes.destinations,
            child: const Text('Content'),
          ),
        ),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('ResponsiveScaffold hides rail below tablet bp (7.4)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveScaffold(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: AdminShellRoutes.destinations,
            child: const Text('PhoneContent'),
          ),
        ),
      );

      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('PhoneContent'), findsOneWidget);
    });

    testWidgets('TwoPane renders master and detail at 1280px (7.5)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 1280,
            height: 600,
            child: TwoPane(
              masterWidth: 360,
              master: Text('Master'),
              detail: Text('Detail'),
            ),
          ),
        ),
      );

      expect(find.text('Master'), findsOneWidget);
      expect(find.text('Detail'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('AdaptiveGrid uses 3 columns on desktop (7.5)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 1280,
            height: 600,
            child: AdaptiveGrid(
              children: List.generate(3, (i) => Text('Card $i')),
            ),
          ),
        ),
      );

      expect(find.byType(GridView), findsOneWidget);
    });
  });

  group('Phase 7 — ScreenUtil density (7.1–7.3, 7.7)', () {
    Future<double> scaledSp(WidgetTester tester, double width) async {
      late double fontSize;
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          ensureScreenSize: true,
          builder: (context, child) {
            fontSize = 14.sp;
            return const MaterialApp(
              home: Scaffold(body: Text('density')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      return fontSize;
    }

    testWidgets('7.1–7.3 sp scales proportionally across phone widths', (tester) async {
      final at360 = await scaledSp(tester, 360);
      final at390 = await scaledSp(tester, 390);
      final at430 = await scaledSp(tester, 430);

      expect(at360, lessThanOrEqualTo(at390));
      expect(at430, greaterThanOrEqualTo(at390));
      expect(at430, lessThan(at390 * 1.15));
    });

    testWidgets('7.7 large text factor does not throw', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.3),
          ),
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (context, child) => const MaterialApp(
              home: Scaffold(body: Text('large font')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 7 — admin shell routes (7.5)', () {
    test('maps employee routes to rail index 0', () {
      expect(
        AdminShellRoutes.selectedIndex(AppRoutes.employeeDetail),
        0,
      );
    });

    test('maps shift schedule routes to rail index 3', () {
      expect(
        AdminShellRoutes.selectedIndex(AppRoutes.adminShiftSchedule),
        3,
      );
    });

    test('maps payroll routes to rail index 4', () {
      expect(AdminShellRoutes.selectedIndex(AppRoutes.payrollPeriods), 4);
    });

    test('maps payment routes to rail index 5', () {
      expect(AdminShellRoutes.selectedIndex(AppRoutes.paymentMain), 5);
    });
  });

  group('Phase 7 — portrait lock (7.9)', () {
    test('main.dart locks portrait orientations', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource, contains('DeviceOrientation.portraitUp'));
      expect(mainSource, contains('DeviceOrientation.portraitDown'));
      expect(mainSource, contains('setPreferredOrientations'));
    });
  });
}
