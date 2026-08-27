import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
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

  test('save draft on active plan omits status from PATCH', () async {
    c.applyLoadedPlan(
      _plan(
        body: const SupportPlanBody(
          disabilityHealth: DisabilityHealthSection(
            primaryDisability: 'ASD',
          ),
        ),
        status: SupportPlanKeys.statusActive,
        nextReviewAt: '2026-09-01',
        id: 'plan-1',
      ),
    );

    c.primaryDisabilityCtrl.text = 'Updated disability';

    when(
      () => mock.patchSupportPlan(any(), any(), any()),
    ).thenAnswer((inv) async {
      final bodyMap = inv.positionalArguments[2] as Map<String, dynamic>;
      return _plan(
        id: 'plan-1',
        status: SupportPlanKeys.statusActive,
        nextReviewAt: '2026-09-01',
        body: SupportPlanBody.fromJson(
          bodyMap['body'] as Map<String, dynamic>?,
        ),
      );
    });

    await c.saveDraft();

    final payload = c.lastSavedPayload;
    expect(payload, isNotNull);
    expect(payload!.containsKey('status'), isFalse);
    expect(c.status.value, SupportPlanKeys.statusActive);

    verify(() => mock.patchSupportPlan('client-1', 'plan-1', any())).called(1);
  });

  test('activate failure leaves prior status; success applies DTO status',
      () async {
    c.applyLoadedPlan(
      _plan(
        body: const SupportPlanBody(
          disabilityHealth: DisabilityHealthSection(
            primaryDisability: 'ASD',
          ),
        ),
        status: SupportPlanKeys.statusDraft,
        nextReviewAt: '2026-09-01',
        id: 'plan-1',
      ),
    );

    when(() => mock.patchSupportPlan(any(), any(), any())).thenThrow(
      const AppFailure(
        code: 'server_error',
        message: 'persist failed',
        presentation: AppFailurePresentation.toast,
      ),
    );

    await c.activate();

    expect(c.status.value, SupportPlanKeys.statusDraft);
    expect(c.errorMessage.value, 'persist failed');

    when(() => mock.patchSupportPlan(any(), any(), any())).thenAnswer(
      (_) async => _plan(
        id: 'plan-1',
        status: SupportPlanKeys.statusActive,
        nextReviewAt: '2026-09-01',
        body: const SupportPlanBody(
          disabilityHealth: DisabilityHealthSection(
            primaryDisability: 'ASD',
          ),
        ),
      ),
    );

    await c.activate();

    expect(c.status.value, SupportPlanKeys.statusActive);
    expect(c.errorMessage.value, isNull);
  });

  test('save draft blocked when limitation Other selected without detail',
      () async {
    c.applyLoadedPlan(_plan(body: const SupportPlanBody(), id: 'plan-1'));
    c.functionalLimitations.add(SupportPlanKeys.limitationOther);

    await c.saveDraft();

    expect(c.errorMessage.value, 'Specify the functional limitation.');
    expect(c.lastSavedPayload, isNull);
    verifyNever(() => mock.patchSupportPlan(any(), any(), any()));
  });

  test('activate blocked when communication Other selected without detail',
      () async {
    c.applyLoadedPlan(
      _plan(
        body: const SupportPlanBody(),
        nextReviewAt: '2026-09-01',
        id: 'plan-1',
      ),
    );
    c.communicationMethods.add(SupportPlanKeys.commOther);

    await c.activate();

    expect(c.errorMessage.value, 'Specify the communication method.');
    verifyNever(() => mock.patchSupportPlan(any(), any(), any()));
  });

  test('save draft includes Other detail keys in body_json when filled',
      () async {
    c.applyLoadedPlan(_plan(body: const SupportPlanBody(), id: 'plan-1'));
    c.functionalLimitations.add(SupportPlanKeys.limitationOther);
    c.limitationOtherCtrl.text = 'Custom limitation';
    c.communicationMethods.add(SupportPlanKeys.commOther);
    c.commOtherCtrl.text = 'Picture board';
    c.serviceCategories.add(SupportPlanKeys.catOther);
    c.catOtherCtrl.text = 'Respite';
    c.setResidenceType(SupportPlanKeys.residenceOther);
    c.residenceOtherCtrl.text = 'Boat';

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

    final bodyJson = c.lastSavedPayload!['body'] as Map<String, dynamic>;
    final dh = bodyJson['disability_health'] as Map<String, dynamic>;
    expect(dh['functional_limitations'], contains('other'));
    expect(dh['limitation_other_detail'], 'Custom limitation');
    expect(dh['communication_methods'], contains('other'));
    expect(dh['comm_other_detail'], 'Picture board');
    expect(bodyJson['service_categories'], contains('other'));
    expect(bodyJson['cat_other_detail'], 'Respite');
    final living = bodyJson['living'] as Map<String, dynamic>;
    expect(living['residence_type'], 'other');
    expect(living['residence_other_detail'], 'Boat');
  });

  test('applyLoadedPlan hydrates Other detail companions', () {
    c.applyLoadedPlan(
      _plan(
        body: SupportPlanBody(
          disabilityHealth: const DisabilityHealthSection(
            functionalLimitations: [SupportPlanKeys.limitationOther],
            communicationMethods: [SupportPlanKeys.commOther],
            limitationOtherDetail: 'Sensory',
            commOtherDetail: 'AAC device',
          ),
          living: const LivingSection(
            residenceType: SupportPlanKeys.residenceOther,
            residenceOtherDetail: 'Granny flat',
          ),
          serviceCategories: const [SupportPlanKeys.catOther],
          catOtherDetail: 'Respite care',
        ),
      ),
    );

    expect(c.functionalLimitations, contains(SupportPlanKeys.limitationOther));
    expect(c.limitationOtherCtrl.text, 'Sensory');
    expect(c.communicationMethods, contains(SupportPlanKeys.commOther));
    expect(c.commOtherCtrl.text, 'AAC device');
    expect(c.residenceType.value, SupportPlanKeys.residenceOther);
    expect(c.residenceOtherCtrl.text, 'Granny flat');
    expect(c.serviceCategories, contains(SupportPlanKeys.catOther));
    expect(c.catOtherCtrl.text, 'Respite care');
  });
}
