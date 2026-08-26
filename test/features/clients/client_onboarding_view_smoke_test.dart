import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/views/client_onboarding_view.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

void main() {
  late _MockClientsRepository mock;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    mock = _MockClientsRepository();
    when(() => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')))
        .thenAnswer((_) async => <FormTemplateSummary>[]);
    Get.put(ClientOnboardingController(repository: mock));
  });

  tearDown(Get.reset);

  testWidgets('onboarding shell shows Identity step and Next', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: ClientOnboardingView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Participant identity'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Identity'), findsWidgets);
    expect(find.text('Legal'), findsWidgets);
  });

  testWidgets('step indicator labels are present', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: ClientOnboardingView()),
    );
    await tester.pumpAndSettle();

    for (final label in ClientOnboardingController.stepLabels) {
      expect(find.text(label), findsWidgets);
    }
  });
}
