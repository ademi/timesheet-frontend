import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/features/contractor_register/controllers/contractor_register_controller.dart';
import 'package:rostiq/features/contractor_register/data/repositories/contractor_register_repository.dart';
import 'package:rostiq/features/contractor_register/views/contractor_register_view.dart';

class _MockRepository extends Mock implements ContractorRegisterRepository {}

void main() {
  late _MockRepository repository;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    repository = _MockRepository();
    Get.put(ContractorRegisterController(repository: repository));
  });

  tearDown(Get.reset);

  testWidgets('register view is Identity-only (no Screening/Legal steps)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: ContractorRegisterView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create your contractor profile'), findsOneWidget);
    expect(
      find.textContaining('complete profile, legal, and documents'),
      findsOneWidget,
    );
    expect(find.text('Account & contact'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    expect(find.text('Screening'), findsNothing);
    expect(find.text('Qualifications'), findsNothing);
    expect(find.text('Checks'), findsNothing);
    expect(find.text('Platform Terms'), findsNothing);
    expect(find.text('Privacy Policy'), findsNothing);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Back'), findsNothing);
  });
}
