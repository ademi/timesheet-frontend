import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/widgets/onboarding/onboarding_identity_step.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late _MockClientsRepository mock;
  late _MockSessionService session;
  late ClientOnboardingController c;

  setUp(() {
    Get.testMode = true;
    mock = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
    ).thenAnswer((_) async => []);
    c = ClientOnboardingController(repository: mock, session: session);
  });

  tearDown(() {
    c.dispose();
    Get.reset();
  });

  testWidgets('hydrated unknown referral builds without dropdown crash',
      (tester) async {
    final hydrated = OnboardingIdentityStep.hydrateReferral('Community Centre');
    c.referralSource.value = hydrated.preset;
    c.referralOtherCtrl.text = hydrated.otherText;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OnboardingIdentityStep(controller: c),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Referral source (other)'), findsOneWidget);
    expect(c.referralOtherCtrl.text, 'Community Centre');
  });

  testWidgets('hydrated unknown sex builds without dropdown crash',
      (tester) async {
    final hydrated = OnboardingIdentityStep.hydrateSexGender('Agender');
    c.sexGender.value = hydrated.preset;
    c.sexGenderOtherCtrl.text = hydrated.otherText;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OnboardingIdentityStep(controller: c),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sex / gender (other)'), findsOneWidget);
    expect(c.sexGenderOtherCtrl.text, 'Agender');
  });
}
