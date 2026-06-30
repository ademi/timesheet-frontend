import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rostiq/app/routes/app_navigation.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/app/routes/route_args.dart';

/// Regression: [Get.toNamed]<bool> throws on web because GetPageRoute<dynamic>
/// is not a subtype of Route<bool?>.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('pushNamedBool opens rate form page', (tester) async {
    const employeeId = 'emp-123';

    await tester.pumpWidget(
      GetMaterialApp(
        getPages: [
          GetPage(
            name: '/',
            page: () => Scaffold(
              body: ElevatedButton(
                key: const Key('open_rate_form'),
                onPressed: () => pushNamedBool(
                  AppRoutes.payrollEmployeeRateForm,
                  arguments: EmployeeRateFormArgs(employeeId: employeeId),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
          GetPage(
            name: AppRoutes.payrollEmployeeRateForm,
            page: () => const Scaffold(body: Text('Rate Form')),
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('open_rate_form')));
    await tester.pumpAndSettle();

    expect(find.text('Rate Form'), findsOneWidget);
  });

  testWidgets('Get.toNamed without generic does not throw', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        getPages: [
          GetPage(
            name: '/',
            page: () => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () => Get.toNamed(AppRoutes.payrollEmployeeRateForm),
                child: const Text('Open'),
              ),
            ),
          ),
          GetPage(
            name: AppRoutes.payrollEmployeeRateForm,
            page: () => const Scaffold(body: Text('Form')),
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('Form'), findsOneWidget);
  });
}
