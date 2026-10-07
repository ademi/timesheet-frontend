import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/compliance_ops/data/repositories/compliance_ops_repository.dart';
import 'package:rostiq/features/payroll/controllers/staff_tenant_settings_controller.dart';
import 'package:rostiq/features/payroll/data/models/payroll_models.dart';
import 'package:rostiq/features/payroll/data/repositories/payroll_repository.dart';

class _MockPayrollRepository extends Mock implements PayrollRepository {}

class _MockComplianceOpsRepository extends Mock
    implements ComplianceOpsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPayrollRepository payroll;
  late _MockComplianceOpsRepository complianceOps;
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late StaffTenantSettingsController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    payroll = _MockPayrollRepository();
    complianceOps = _MockComplianceOpsRepository();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantId).thenReturn(RxnString('tenant-1'));
    controller = StaffTenantSettingsController(
      payroll: payroll,
      complianceOps: complianceOps,
      session: session,
      clients: clients,
    );
  });

  tearDown(() {
    Get.closeAllSnackbars();
    controller.onClose();
    Get.reset();
  });

  test('save with bad ABN checksum does not call patchTenant', () async {
    controller.providerAbnCtrl.text = '12345678901';

    await controller.save();

    expect(controller.errorMessage.value, contains('checksum'));
    verifyNever(
      () => payroll.patchTenant(
        any(),
        timezone: any(named: 'timezone'),
        publicHolidayJurisdiction: any(named: 'publicHolidayJurisdiction'),
        geofenceOutsidePolicy: any(named: 'geofenceOutsidePolicy'),
        providerAbn: any(named: 'providerAbn'),
        ndisProviderRegistrationStatus: any(
          named: 'ndisProviderRegistrationStatus',
        ),
        defaultProgressNoteTemplateId: any(
          named: 'defaultProgressNoteTemplateId',
        ),
        setDefaultProgressNoteTemplate: any(
          named: 'setDefaultProgressNoteTemplate',
        ),
      ),
    );
  });

  testWidgets('save with valid spaced ABN patches normalized digits', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(home: Scaffold(body: Container())),
    );

    when(
      () => payroll.patchTenant(
        any(),
        timezone: any(named: 'timezone'),
        publicHolidayJurisdiction: any(named: 'publicHolidayJurisdiction'),
        geofenceOutsidePolicy: any(named: 'geofenceOutsidePolicy'),
        providerAbn: any(named: 'providerAbn'),
        ndisProviderRegistrationStatus: any(
          named: 'ndisProviderRegistrationStatus',
        ),
        defaultProgressNoteTemplateId: any(
          named: 'defaultProgressNoteTemplateId',
        ),
        setDefaultProgressNoteTemplate: any(
          named: 'setDefaultProgressNoteTemplate',
        ),
      ),
    ).thenAnswer(
      (_) async => const TenantSettingsOut(
        id: 'tenant-1',
        name: 'Demo',
        providerAbn: '53004085616',
      ),
    );

    controller.providerAbnCtrl.text = '53 004 085 616';

    await controller.save();
    await tester.pump();

    expect(controller.errorMessage.value, isNull);
    verify(
      () => payroll.patchTenant(
        'tenant-1',
        timezone: any(named: 'timezone'),
        publicHolidayJurisdiction: any(named: 'publicHolidayJurisdiction'),
        geofenceOutsidePolicy: any(named: 'geofenceOutsidePolicy'),
        providerAbn: '53004085616',
        ndisProviderRegistrationStatus: any(
          named: 'ndisProviderRegistrationStatus',
        ),
        defaultProgressNoteTemplateId: any(
          named: 'defaultProgressNoteTemplateId',
        ),
        setDefaultProgressNoteTemplate: any(
          named: 'setDefaultProgressNoteTemplate',
        ),
      ),
    ).called(1);

    Get.closeAllSnackbars();
    await tester.pump();
  });
}
