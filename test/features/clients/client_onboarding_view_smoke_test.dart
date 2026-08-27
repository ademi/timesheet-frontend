import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/views/client_onboarding_view.dart';
import 'package:rostiq/shared/widgets/floating_error_notice.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late _MockClientsRepository mock;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    mock = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
    ).thenAnswer((_) async => <FormTemplateSummary>[]);
    Get.put(ClientOnboardingController(repository: mock, session: session));
  });

  tearDown(Get.reset);

  testWidgets('onboarding shell shows Identity step and Next', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientOnboardingView()));
    await tester.pumpAndSettle();

    expect(find.text('Participant identity'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Identity'), findsWidgets);
    expect(find.text('Legal'), findsWidgets);
  });

  testWidgets('step indicator labels are present', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientOnboardingView()));
    await tester.pumpAndSettle();

    for (final label in ClientOnboardingController.stepLabels) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('error notice sits above footer, not inside ListView', (
    tester,
  ) async {
    Get.find<ClientOnboardingController>().errorMessage.value =
        'NDIS number is required.';
    await tester.pumpWidget(const GetMaterialApp(home: ClientOnboardingView()));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingErrorNotice), findsOneWidget);
    expect(find.text('NDIS number is required.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(FloatingErrorNotice),
      ),
      findsNothing,
    );
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Skip carer sits in footer above Next, not in ListView', (
    tester,
  ) async {
    final c = Get.find<ClientOnboardingController>();
    c.step.value = 3;
    c.emergencySaved.value = true;
    c.beginCarerDraft();

    await tester.pumpWidget(const GetMaterialApp(home: ClientOnboardingView()));
    await tester.pumpAndSettle();

    expect(find.text('Skip carer'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Skip carer'),
      ),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.text('Skip carer')).dy,
      lessThan(tester.getTopLeft(find.text('Next')).dy),
    );
  });

  testWidgets('Skip nominee sits in footer above Next, not in ListView', (
    tester,
  ) async {
    final c = Get.find<ClientOnboardingController>();
    c.dob.value = DateTime(1990, 1, 1);
    c.step.value = 4;

    await tester.pumpWidget(const GetMaterialApp(home: ClientOnboardingView()));
    await tester.pumpAndSettle();

    expect(find.text('Skip nominee'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Skip nominee'),
      ),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.text('Skip nominee')).dy,
      lessThan(tester.getTopLeft(find.text('Next')).dy),
    );
  });
}
