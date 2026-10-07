import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 9, 27, 9);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Demo Client',
  status: 'active',
  metadata: const {'onboarding_incomplete': true},
  createdAt: _now,
  updatedAt: _now,
  email: 'demo@example.com',
  phone: '+61400000000',
  dob: '1990-01-01',
);

void main() {
  late _MockClientsRepository repository;
  late _MockSessionService session;
  late ClientOnboardingController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    repository = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => repository.getClient(_client.id),
    ).thenAnswer((_) async => _client);
    when(
      () => repository.getClientProfile(any()),
    ).thenAnswer((_) async => const ClientProfileBundle(facts: []));
    when(() => repository.listClientTypes()).thenAnswer((_) async => []);
    when(
      () => repository.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
    ).thenAnswer((_) async => []);
    controller = ClientOnboardingController(
      repository: repository,
      session: session,
    );
    Get.put(controller);
  });

  tearDown(() {
    Get.reset();
  });

  test('ensureHydratedFromRoute restores id and step from URL params', () async {
    Get.parameters['id'] = _client.id;
    Get.parameters['step'] = '3';
    Get.routing.args = null;

    await controller.ensureHydratedFromRoute();

    expect(controller.client.value?.id, _client.id);
    expect(controller.step.value, 3);
    expect(Get.parameters['id'], _client.id);
    expect(Get.parameters['step'], '3');
    verify(() => repository.getClient(_client.id)).called(1);
  });

  test('ensureHydratedFromRoute prefers args ClientOut then applies step', () async {
    Get.routing.args = _client;
    Get.parameters['step'] = '2';
    Get.parameters.remove('id');

    await controller.ensureHydratedFromRoute();

    expect(controller.client.value?.id, _client.id);
    expect(controller.step.value, 2);
    verifyNever(() => repository.getClient(any()));
  });

  test('syncOnboardingRoute writes step into Get.parameters', () {
    controller.client.value = _client;
    controller.step.value = 4;
    controller.syncOnboardingRoute();

    expect(Get.parameters['step'], '4');
    expect(Get.parameters['id'], _client.id);
  });

  test('syncOnboardingRoute is a no-op when URL already matches', () {
    Get.testMode = true;
    // Without a bound GoRouter, usesGoRouter is false — params still update.
    controller.client.value = _client;
    controller.step.value = 0;
    Get.parameters['step'] = '0';
    Get.parameters['id'] = _client.id;
    controller.syncOnboardingRoute();
    expect(Get.parameters['step'], '0');
    expect(Get.parameters['id'], _client.id);
  });
}
