import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/clients/data/models/support_plan_models.dart';
import 'package:rostiq/features/visits/controllers/visit_shift_brief_controller.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

const sampleBrief = ShiftBriefDto(
  clientId: 'c1',
  clientName: 'Ada',
  planBodyInvalid: false,
  allergies: 'Peanuts',
  accessNotes: 'Gate code 1234',
  routines: 'Breakfast 8am',
  medicationSchedule: '8am meds',
  behaviourSupportPlan: true,
  communicationMethods: ['verbal'],
  goals: [
    {
      'ndis_goal': 'Cook independently',
      'strategy': 'Prompt fade',
      'worker_instructions': 'Use visual card',
    },
  ],
  triggers: 'Loud noise',
);

void main() {
  late _MockVisitsRepository mock;
  late VisitShiftBriefController c;

  setUp(() {
    mock = _MockVisitsRepository();
    c = VisitShiftBriefController(repo: mock);
  });

  tearDown(() {
    c.onClose();
  });

  test('loads shift brief for visit', () async {
    when(() => mock.getVisitShiftBrief('v1'))
        .thenAnswer((_) async => sampleBrief);
    await c.load('v1');
    expect(c.brief.value?.routines, 'Breakfast 8am');
    expect(c.isLoading.value, isFalse);
    expect(c.errorMessage.value, isNull);
  });

  test('load surfaces AppFailure and clears brief', () async {
    when(() => mock.getVisitShiftBrief('v1')).thenThrow(
      const AppFailure(
        code: 'forbidden',
        message: 'Not assigned to this visit',
        presentation: AppFailurePresentation.inline,
      ),
    );
    c.brief.value = sampleBrief;
    await c.load('v1');
    expect(c.brief.value, isNull);
    expect(c.errorMessage.value, 'Not assigned to this visit');
    expect(c.isLoading.value, isFalse);
  });

  test('loads plan_body_invalid brief with allergies preserved (CR1)', () async {
    const invalid = ShiftBriefDto(
      clientId: 'c1',
      clientName: 'Ada',
      planBodyInvalid: true,
      allergies: 'Peanuts',
      accessNotes: 'Gate code 1234',
      supportPlanId: 'plan-1',
    );
    when(() => mock.getVisitShiftBrief('v1')).thenAnswer((_) async => invalid);
    await c.load('v1');
    expect(c.brief.value?.planBodyInvalid, isTrue);
    expect(c.brief.value?.allergies, 'Peanuts');
    expect(c.brief.value?.accessNotes, 'Gate code 1234');
    expect(c.brief.value?.routines, isNull);
  });
}
