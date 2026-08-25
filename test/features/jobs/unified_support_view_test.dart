import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/unified_support_controller.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/jobs/utils/recurrence_rrule_builder.dart';
import 'package:rostiq/features/jobs/utils/schedule_hours_warn.dart';
import 'package:rostiq/features/jobs/utils/unified_support_args.dart';
import 'package:rostiq/features/jobs/views/unified_support_view.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late UnifiedSupportController controller;
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockEngagementsRepository engagements;
  late _MockShiftsRepository shifts;
  late _MockSessionService session;

  final now = DateTime.utc(2026, 8, 13, 9);
  final client = ClientOut(
    id: 'client-1',
    tenantId: 'tenant-1',
    fullName: 'Sam Lee',
    status: 'active',
    metadata: const {},
    createdAt: now,
    updatedAt: now,
  );
  final site = ClientSiteOut(
    id: 'site-1',
    tenantId: 'tenant-1',
    clientId: 'client-1',
    name: 'Home',
    geofenceRadiusM: 100,
    isPrimary: true,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    Get.reset();
    Get.testMode = true;
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    engagements = _MockEngagementsRepository();
    shifts = _MockShiftsRepository();
    session = _MockSessionService();

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantId).thenReturn(RxnString());
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(() => clients.getClient(any())).thenAnswer((_) async => client);
    when(() => clients.listSites(any())).thenAnswer((_) async => [site]);
    when(() => clients.getClientProfile(any())).thenAnswer(
      (_) async => const ClientProfileBundle(
        clientType: ClientTypeOut(
          id: 'type-1',
          code: 'patient',
          name: 'Patient',
          isActive: true,
          sortOrder: 0,
        ),
      ),
    );
    when(() => jobs.listFormTemplates(tenantLevel: true))
        .thenAnswer((_) async => []);
    when(() => engagements.listTenantEngagements())
        .thenAnswer((_) async => []);

    controller = UnifiedSupportController(
      jobsRepository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      shiftsRepository: shifts,
      session: session,
      args: UnifiedSupportArgs.forClient(
        client,
        mode: UnifiedSupportMode.ongoing,
      ),
    );
    Get.put(controller);
  });

  tearDown(Get.reset);

  testWidgets('shows amber warn on schedule step for atypical hours', (
    tester,
  ) async {
    await controller.load();
    controller.step.value = 2;
    controller.frequency.value = RecurrenceFrequency.daily;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    expect(find.text(kAtypicalScheduleHoursMessage), findsOneWidget);
  });

  testWidgets('schedule step rebuilds when start time and weekdays change', (
    tester,
  ) async {
    await controller.load();
    controller.step.value = 2;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);

    controller.startTime.value = const TimeOfDay(hour: 14, minute: 30);
    await tester.pump();

    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('09:00'), findsNothing);

    controller.endDate.value = DateTime(2027, 3, 15);
    await tester.pump();

    expect(
      find.text(MaterialLocalizations.of(
        tester.element(find.byType(UnifiedSupportView)),
      ).formatMediumDate(DateTime(2027, 3, 15))),
      findsOneWidget,
    );

    expect(find.widgetWithText(FilterChip, 'MO'), findsOneWidget);
    final mondayChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'MO'),
    );
    expect(mondayChip.selected, isTrue);

    controller.toggleWeekday(DateTime.monday);
    controller.toggleWeekday(DateTime.wednesday);
    await tester.pump();

    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'MO')).selected,
      isFalse,
    );
    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'WE')).selected,
      isTrue,
    );
  });
}
