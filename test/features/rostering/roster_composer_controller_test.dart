import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/rostering/data/composer_facade.dart';
import 'package:rostiq/features/rostering/data/composer_models.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/rostering/presentation/composer/roster_composer_controller.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

ShiftOut _shift(String id, {String status = 'draft'}) => ShiftOut(
  id: id,
  tenantId: 't1',
  jobId: 'job-1',
  jobTitle: 'Support',
  scheduledStart: DateTime.utc(2026, 10, 4, 9),
  scheduledEnd: DateTime.utc(2026, 10, 4, 12),
  requiredSlots: 1,
  openSlots: 1,
  status: status,
  createdAt: DateTime.utc(2026, 10, 4),
  updatedAt: DateTime.utc(2026, 10, 4),
);

ClientOut _client(String id) => ClientOut(
  id: id,
  tenantId: 't1',
  fullName: 'Sam',
  status: 'active',
  metadata: const {},
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late ComposerFacade facade;
  final navigations = <(String, dynamic)>[];

  setUpAll(() {
    registerFallbackValue(
      ShiftCreateRequest(
        jobId: 'j',
        scheduledStart: DateTime.utc(2026, 1, 1),
        scheduledEnd: DateTime.utc(2026, 1, 1, 1),
      ),
    );
    registerFallbackValue(const ShiftPatchRequest());
    registerFallbackValue(
      const ShiftParticipantsReplaceRequest(participants: []),
    );
    registerFallbackValue(
      JobCreateRequest(kind: 'program', title: 'Group session'),
    );
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    navigations.clear();
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    facade = ComposerFacade(shifts: shifts, jobs: jobs);

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantTimezone).thenReturn(RxnString('Australia/Sydney'));
    when(() => clients.listClients()).thenAnswer((_) async => [_client('c1')]);
    when(() => clients.getClient(any())).thenAnswer((_) async => _client('c1'));
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut());
    when(
      () => shifts.fetchPlaceOptions(participantIds: any(named: 'participantIds')),
    ).thenAnswer((_) async => const PlaceOptionsOut());
    when(
      () => jobs.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
    ).thenAnswer((_) async => []);
    when(
      () => shifts.fetchAssignContext(
        from: any(named: 'from'),
        to: any(named: 'to'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer((_) async => const AssignContextOut());
    when(() => jobs.ensureOngoingSupport(any())).thenAnswer(
      (_) async => JobOut(
        id: 'standing-1',
        tenantId: 't1',
        kind: 'standing',
        status: 'open',
        title: 'Sam support',
        clientId: 'c1',
        geofenceRadiusM: 100,
        geofenceMode: 'informational',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    when(() => jobs.getJob(any())).thenAnswer(
      (_) async => JobOut(
        id: 'standing-1',
        tenantId: 't1',
        kind: 'standing',
        status: 'open',
        title: 'Sam support',
        clientId: 'c1',
        geofenceRadiusM: 100,
        geofenceMode: 'informational',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
  });

  tearDown(Get.reset);

  RosterComposerController build(RosterComposerArgs args) {
    final c = RosterComposerController(
      facade: facade,
      clientsRepository: clients,
      session: session,
      args: args,
      onNavigate: (route, arguments) => navigations.add((route, arguments)),
    );
    Get.put(c);
    return c;
  }

  test('published shiftId bounces to staffShiftDetail', () async {
    when(() => shifts.getComposer('pub-1')).thenAnswer(
      (_) async => ComposerShiftOut(shift: _shift('pub-1', status: 'published')),
    );

    final c = build(const RosterComposerArgs(shiftId: 'pub-1'));
    await c.retryHydrate();

    expect(navigations, isNotEmpty);
    expect(navigations.first.$1, AppRoutes.staffShiftDetail);
    expect((navigations.first.$2 as ShiftOut).id, 'pub-1');
  });

  test('published seed shift bounces without hydrate call', () async {
    final c = build(
      RosterComposerArgs(
        shiftId: 'pub-2',
        shift: _shift('pub-2', status: 'published'),
      ),
    );
    await c.retryHydrate();

    verifyNever(() => shifts.getComposer(any()));
    expect(navigations.first.$1, AppRoutes.staffShiftDetail);
  });

  test('composerSeed applies ComposerShiftOut without getComposer', () async {
    final draft = _shift('copy-1', status: 'draft');
    final seed = ComposerShiftOut(
      shift: draft,
      formOverrides: const [],
      resolvedFormsPreview: const [],
    );

    final c = build(
      RosterComposerArgs(
        shiftId: draft.id,
        shift: draft,
        composerSeed: seed,
      ),
    );
    await c.retryHydrate();

    verifyNever(() => shifts.getComposer(any()));
    expect(c.draft.value.shiftId, 'copy-1');
    expect(c.errorMessage.value, isNull);
  });

  test('one-session preset hides allocation', () async {
    final c = build(
      RosterComposerArgs(clientId: 'c1', preset: ComposerPreset.oneSession),
    );
    await c.retryHydrate();

    expect(c.showsAllocation, isFalse);
    c.setPreset(ComposerPreset.group);
    expect(c.showsAllocation, isTrue);
  });

  test('preset switch clears jobId so group cannot reuse standing job', () async {
    final c = build(
      RosterComposerArgs(clientId: 'c1', preset: ComposerPreset.oneSession),
    );
    await c.retryHydrate();
    c.draft.value = c.draft.value.copyWith(jobId: 'standing-1');

    c.setPreset(ComposerPreset.group);

    expect(c.draft.value.jobId, isNull);
    expect(c.draft.value.preset, ComposerPreset.group);
  });

  test('hydrate restores labelled place from placeLabel + coords', () async {
    final labelled = ShiftOut(
      id: 'lab-1',
      tenantId: 't1',
      jobId: 'job-1',
      jobTitle: 'Support',
      scheduledStart: DateTime.utc(2026, 10, 4, 9),
      scheduledEnd: DateTime.utc(2026, 10, 4, 12),
      requiredSlots: 1,
      openSlots: 1,
      status: 'draft',
      placeLabel: 'Park gate',
      postalCode: '2000',
      placeLatitude: -33.86,
      placeLongitude: 151.21,
      createdAt: DateTime.utc(2026, 10, 4),
      updatedAt: DateTime.utc(2026, 10, 4),
    );
    when(() => shifts.getComposer('lab-1')).thenAnswer(
      (_) async => ComposerShiftOut(shift: labelled),
    );

    final c = build(const RosterComposerArgs(shiftId: 'lab-1'));
    await c.retryHydrate();

    final place = c.draft.value.place;
    expect(place, isA<ShiftPlaceLabelled>());
    place as ShiftPlaceLabelled;
    expect(place.label, 'Park gate');
    expect(place.postalCode, '2000');
    expect(place.latitude, -33.86);
    expect(place.longitude, 151.21);
  });

  test('saveDraft persists selected workers via create contractorIds', () async {
    when(() => jobs.createJob(any())).thenAnswer(
      (_) async => JobOut(
        id: 'program-1',
        tenantId: 't1',
        kind: 'program',
        status: 'open',
        title: 'Group session',
        branchId: 'b1',
        geofenceRadiusM: 100,
        geofenceMode: 'informational',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    when(() => shifts.createShift(any())).thenAnswer((invocation) async {
      final body = invocation.positionalArguments.first as ShiftCreateRequest;
      return ShiftOut(
        id: 'new-1',
        tenantId: 't1',
        jobId: body.jobId,
        jobTitle: 'Group',
        scheduledStart: body.scheduledStart,
        scheduledEnd: body.scheduledEnd,
        requiredSlots: body.requiredSlots,
        openSlots: body.requiredSlots - body.contractorIds.length,
        status: 'draft',
        assignments: [
          for (final id in body.contractorIds)
            ShiftAssignmentOut(
              id: 'a-$id',
              contractorId: id,
              engagementId: 'e-$id',
              contractorName: 'Worker',
              visitId: 'v-$id',
              source: 'staff',
              status: 'active',
            ),
        ],
        createdAt: DateTime.utc(2026, 10, 4),
        updatedAt: DateTime.utc(2026, 10, 4),
      );
    });
    when(
      () => shifts.fetchPlaceOptions(participantIds: any(named: 'participantIds')),
    ).thenAnswer(
      (_) async => const PlaceOptionsOut(
        branches: [PlaceBranchOption(id: 'b1', name: 'Centre')],
      ),
    );

    final c = build(
      const RosterComposerArgs(preset: ComposerPreset.group, participantId: 'c1'),
    );
    await c.retryHydrate();
    await c.loadPlaceOptions();
    c.setPlace(const ShiftPlaceIn.branch('b1'));
    c.draft.value = c.draft.value.copyWith(
      participantIds: ['c1'],
      contractorIds: ['w1'],
    );

    final ok = await c.saveDraft();
    expect(ok, isTrue);

    final body =
        verify(() => shifts.createShift(captureAny())).captured.single
            as ShiftCreateRequest;
    expect(body.contractorIds, ['w1']);
    expect(c.draft.value.contractorIds, ['w1']);
    expect(c.assignments.map((a) => a.contractorId), ['w1']);
  });

  test('group create uses program job, not ensureOngoingSupport host', () async {
    when(() => jobs.createJob(any())).thenAnswer(
      (_) async => JobOut(
        id: 'program-1',
        tenantId: 't1',
        kind: 'program',
        status: 'open',
        title: 'Group session',
        branchId: 'b1',
        geofenceRadiusM: 100,
        geofenceMode: 'informational',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    when(() => shifts.createShift(any())).thenAnswer(
      (_) async => _shift('new-1'),
    );
    when(
      () => shifts.fetchPlaceOptions(participantIds: any(named: 'participantIds')),
    ).thenAnswer(
      (_) async => const PlaceOptionsOut(
        branches: [
          PlaceBranchOption(id: 'b1', name: 'Centre'),
        ],
      ),
    );

    final c = build(
      const RosterComposerArgs(preset: ComposerPreset.group, participantId: 'c1'),
    );
    await c.retryHydrate();
    await c.loadPlaceOptions();
    c.setPlace(const ShiftPlaceIn.branch('b1'));
    c.draft.value = c.draft.value.copyWith(participantIds: ['c1']);

    final ok = await c.saveDraft();
    expect(ok, isTrue);

    final jobBody =
        verify(() => jobs.createJob(captureAny())).captured.single
            as JobCreateRequest;
    expect(jobBody.kind, 'program');
    verifyNever(() => jobs.ensureOngoingSupport(any()));
  });
}
