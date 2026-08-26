import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/clients/controllers/support_plan_controller.dart';
import 'package:rostiq/features/clients/data/models/support_plan_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/support_plan_keys.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

final _now = DateTime.utc(2026, 8, 26, 9);

SupportPlanDto _plan({
  required SupportPlanBody body,
  bool bodyInvalid = false,
  String status = SupportPlanKeys.statusDraft,
  String? nextReviewAt,
  String id = 'plan-1',
}) {
  return SupportPlanDto(
    id: id,
    clientId: 'client-1',
    status: status,
    nextReviewAt: nextReviewAt,
    body: body,
    bodyInvalid: bodyInvalid,
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late _MockClientsRepository mock;
  late SupportPlanController c;

  setUp(() {
    mock = _MockClientsRepository();
    c = SupportPlanController(
      repository: mock,
      clientId: 'client-1',
      planId: 'plan-1',
    );
  });

  tearDown(() {
    c.onClose();
  });

  test('cannot activate without next_review_at when marking active', () {
    c.status.value = 'active';
    c.nextReviewAt.value = null;
    expect(c.canActivate, isFalse);
  });

  test('load shows repair banner when GET body_invalid flag set', () {
    // CR3: GET returns 200 with body_invalid=true (not 422)
    c.applyLoadedPlan(
      _plan(
        body: const SupportPlanBody(),
        bodyInvalid: true,
      ),
    );
    expect(c.needsBodyRepair.value, isTrue);
  });

  test('edit goals only → PATCH payload still has prior risk/disability_health',
      () async {
    final prior = SupportPlanBody(
      disabilityHealth: const DisabilityHealthSection(
        primaryDisability: 'ASD',
        supportIntensity: SupportPlanKeys.intensityComplex,
      ),
      risk: const RiskSection(
        summary: 'Fall risk',
        crisisResponse: 'Call coordinator',
      ),
      goals: const [
        SupportPlanGoal(
          id: 'g1',
          ndisGoal: 'Original goal',
          strategy: 'S',
          measure: 'M',
          sortOrder: 0,
        ),
      ],
    );
    c.applyLoadedPlan(_plan(body: prior, id: 'plan-1'));

    // Edit goals only
    c.goals.first.ndisGoal.text = 'Updated goal';

    when(
      () => mock.patchSupportPlan(any(), any(), any()),
    ).thenAnswer((inv) async {
      final bodyMap = inv.positionalArguments[2] as Map<String, dynamic>;
      return _plan(
        id: 'plan-1',
        body: SupportPlanBody.fromJson(
          bodyMap['body'] as Map<String, dynamic>?,
        ),
      );
    });

    await c.saveDraft();

    final payload = c.lastSavedPayload;
    expect(payload, isNotNull);
    expect(payload!.containsKey('body'), isTrue);
    final bodyJson = payload['body'] as Map<String, dynamic>;
    expect(bodyJson['disability_health'], isA<Map>());
    expect(
      (bodyJson['disability_health'] as Map)['primary_disability'],
      'ASD',
    );
    expect(bodyJson['risk'], isA<Map>());
    expect((bodyJson['risk'] as Map)['summary'], 'Fall risk');
    expect(
      ((bodyJson['goals'] as List).first as Map)['ndis_goal'],
      'Updated goal',
    );

    verify(() => mock.patchSupportPlan('client-1', 'plan-1', any())).called(1);
  });
}
