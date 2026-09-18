import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/clients/controllers/support_plan_controller.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/widgets/steps/support_plan_health_step.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
}

void main() {
  late _MockClientsRepository mock;
  late SupportPlanController c;

  setUp(() {
    mock = _MockClientsRepository();
    c = SupportPlanController(repository: mock, clientId: 'c1');
  });

  tearDown(() {
    c.onClose();
  });

  test('nextStep increments wizardStep until last step', () {
    expect(c.wizardStep.value, 0);
    c.nextStep();
    expect(c.wizardStep.value, 1);
    for (var i = 0; i < 10; i++) {
      c.nextStep();
    }
    expect(c.wizardStep.value, SupportPlanController.wizardStepCount - 1);
  });

  test('prevStep decrements wizardStep but not below zero', () {
    c.wizardStep.value = 3;
    c.prevStep();
    expect(c.wizardStep.value, 2);
    c.wizardStep.value = 0;
    c.prevStep();
    expect(c.wizardStep.value, 0);
  });

  testWidgets('Health step shows primary disability field', (tester) async {
    await tester.pumpWidget(_wrap(SupportPlanHealthStep(controller: c)));
    expect(find.text('Primary disability'), findsOneWidget);
  });
}
