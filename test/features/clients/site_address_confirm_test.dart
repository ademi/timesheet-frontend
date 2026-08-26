import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/widgets/site_form_fields.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeGeocodeRequest extends Fake implements GeocodeRequest {}

class _FakeSiteWriteRequest extends Fake implements ClientSiteWriteRequest {}

final _now = DateTime.utc(2026, 8, 26, 9);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Sam Lee',
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockClientsRepository clients;
  late _MockJobsRepository jobs;
  late _MockSessionService session;
  late ClientsController controller;

  setUpAll(() {
    registerFallbackValue(_FakeGeocodeRequest());
    registerFallbackValue(_FakeSiteWriteRequest());
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clients = _MockClientsRepository();
    jobs = _MockJobsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => clients.listClients()).thenAnswer((_) async => [_client]);
    when(() => clients.getClientProfilePhoto(any())).thenAnswer(
      (_) async => const ProfilePhotoOut(hasPhoto: false),
    );
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: jobs,
    );
    controller.selected.value = _client;
    Get.put(controller);
  });

  tearDown(Get.reset);

  group('primary postal validation', () {
    test('saveSite blocks primary site with empty postal', () async {
      controller.editingSite = null;
      controller.siteNameCtrl.text = 'Home';
      controller.siteAddressCtrl.text = '1 Test St';
      controller.siteCityCtrl.text = 'Sydney';
      controller.sitePostalCtrl.clear();
      controller.siteIsPrimary.value = true;
      controller.siteLatCtrl.text = '-33.86';
      controller.siteLngCtrl.text = '151.20';
      controller.addressConfirmed.value = true;
      controller.geocodeFormattedAddress.value =
          '1 Test St, Sydney NSW 2000, Australia';

      await controller.saveSite();

      expect(
        controller.errorMessage.value,
        'Postal code is required for the primary site.',
      );
      verifyNever(() => clients.createSite(any(), any()));
    });

    testWidgets('primaryMode marks postal as required', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SiteFormFields(
                controller: controller,
                primaryMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Postal code *'), findsOneWidget);
      expect(controller.siteIsPrimary.value, isTrue);
    });
  });

  group('geocode confirm flow', () {
    testWidgets('lookup shows formatted address with Confirm and Edit',
        (tester) async {
      when(() => clients.geocode(any())).thenAnswer(
        (_) async => const GeocodeResponse(
          latitude: -33.86,
          longitude: 151.2,
          formattedAddress: '1 Test St, Sydney NSW 2000, Australia',
          confidence: 'high',
        ),
      );

      controller.siteAddressCtrl.text = '1 Test St';
      controller.siteCityCtrl.text = 'Sydney';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SiteFormFields(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Look up address'), findsOneWidget);
      expect(find.text('Access notes'), findsOneWidget);

      await tester.ensureVisible(find.text('Look up address'));
      await tester.tap(find.text('Look up address'));
      await tester.pumpAndSettle();

      expect(
        find.text('1 Test St, Sydney NSW 2000, Australia'),
        findsOneWidget,
      );
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(controller.addressConfirmed.value, isFalse);

      await tester.ensureVisible(find.text('Confirm'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(controller.addressConfirmed.value, isTrue);
      expect(find.text('Confirmed address'), findsOneWidget);
    });

    testWidgets('low confidence blocks confirm panel', (tester) async {
      when(() => clients.geocode(any())).thenAnswer(
        (_) async => const GeocodeResponse(
          latitude: -33.86,
          longitude: 151.2,
          formattedAddress: 'Somewhere vague',
          confidence: 'low',
        ),
      );

      controller.siteAddressCtrl.text = '1 Test St';
      controller.siteCityCtrl.text = 'Sydney';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SiteFormFields(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await controller.lookupSiteAddress();
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsNothing);
      expect(controller.geocodeFormattedAddress.value, isNull);
      expect(controller.addressConfirmed.value, isFalse);
      expect(
        controller.errorMessage.value,
        contains('low confidence'),
      );
      expect(find.text('Look up address'), findsOneWidget);
    });

    test('saveSite requires confirm before create', () async {
      controller.editingSite = null;
      controller.siteNameCtrl.text = 'Home';
      controller.siteAddressCtrl.text = '1 Test St';
      controller.siteCityCtrl.text = 'Sydney';
      controller.sitePostalCtrl.text = '2000';
      controller.siteIsPrimary.value = true;
      controller.addressConfirmed.value = false;
      controller.siteLatCtrl.clear();
      controller.siteLngCtrl.clear();

      await controller.saveSite();

      expect(
        controller.errorMessage.value,
        'Look up and confirm the address before saving.',
      );
    });
  });
}
