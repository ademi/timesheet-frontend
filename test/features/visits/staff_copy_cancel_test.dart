import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/rostering/data/composer_models.dart';
import 'package:rostiq/features/rostering/domain/occurrence_draft.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeHorizonRequest extends Fake implements HorizonRequest {}

class _FakeShiftCopyRequest extends Fake implements ShiftCopyRequest {}

final _now = DateTime.utc(2026, 8, 14, 9);

ShiftOut _shift({
  String id = 'shift-1',
  int requiredSlots = 2,
  String status = 'published',
  List<ShiftParticipantOut> participants = const [],
}) {
  return ShiftOut(
    id: id,
    tenantId: 'tenant-1',
    jobId: 'job-1',
    jobTitle: 'Morning support',
    clientName: 'Jane Client',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 3)),
    requiredSlots: requiredSlots,
    openSlots: requiredSlots,
    status: status,
    assignments: const [],
    participants: participants,
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockEngagementsRepository engagements;
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late StaffVisitsController controller;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 1, 1));
    registerFallbackValue(_FakeHorizonRequest());
    registerFallbackValue(_FakeShiftCopyRequest());
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    visits = _MockVisitsRepository();
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    engagements = _MockEngagementsRepository();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).thenAnswer((_) async => <ShiftOut>[]);
    when(
      () => visits.fetchRosterOverlay(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => const RosterOverlayOut(contractors: []));
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
    when(
      () => jobs.ensureHorizon(any()),
    ).thenAnswer((_) async => HorizonOut.empty);
    when(() => engagements.listTenantEngagements()).thenAnswer((_) async => []);
    controller = StaffVisitsController(
      repository: visits,
      shiftsRepository: shifts,
      jobsRepository: jobs,
      engagementsRepository: engagements,
      clientsRepository: clients,
      session: session,
    );
  });

  tearDown(Get.reset);

  test('copyTile posts copy and returns ComposerShiftOut composer args', () async {
    final shift = _shift();
    final copied = _shift(
      id: 'shift-2',
      status: 'draft',
      participants: const [
        ShiftParticipantOut(
          id: 'sp-1',
          participantId: 'c-1',
          participantName: 'Maya',
          status: 'active',
        ),
        ShiftParticipantOut(
          id: 'sp-2',
          participantId: 'c-2',
          participantName: 'Jordan',
          status: 'active',
        ),
      ],
    );
    final composer = ComposerShiftOut(shift: copied);
    when(() => shifts.copyShift(any(), any())).thenAnswer((_) async => composer);

    final args = await controller.copyTile(
      source: shift,
      start: DateTime(2026, 8, 14, 9),
      end: DateTime(2026, 8, 14, 12),
    );

    final req =
        verify(() => shifts.copyShift(shift.id, captureAny())).captured.single
            as ShiftCopyRequest;
    expect(req.status, 'draft');
    expect(req.scheduledStart.toUtc(), DateTime(2026, 8, 14, 9).toUtc());
    expect(req.scheduledEnd.toUtc(), DateTime(2026, 8, 14, 12).toUtc());
    expect(args, isNotNull);
    expect(args!.composerSeed, same(composer));
    expect(args.shiftId, 'shift-2');
    expect(args.preset, ComposerPreset.group);
    expect(controller.lastCopyComposerArgs, same(args));
    // No board reload before navigate — listShifts must not be re-fetched here.
    verifyNever(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    );
  });

  test('cancelThisOccurrence calls cancelShift', () async {
    final shift = _shift();
    when(() => shifts.cancelShift(shift.id)).thenAnswer((_) async => shift);

    await controller.cancelThisOccurrence(shift.id);

    verify(() => shifts.cancelShift(shift.id)).called(1);
  });
}
