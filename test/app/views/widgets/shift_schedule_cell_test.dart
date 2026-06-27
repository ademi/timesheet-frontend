import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yemen_gate_attendance_app/app/controllers/shift_schedule_controller.dart';
import 'package:yemen_gate_attendance_app/app/data/models/scheduling/board_day.dart';
import 'package:yemen_gate_attendance_app/app/data/models/scheduling/board_employee.dart';
import 'package:yemen_gate_attendance_app/app/data/models/scheduling/board_meta.dart';
import 'package:yemen_gate_attendance_app/app/data/models/scheduling/schedule_board.dart';
import 'package:yemen_gate_attendance_app/app/data/models/scheduling/scheduling_date_utils.dart';
import 'package:yemen_gate_attendance_app/app/data/models/scheduling/shift_status.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/branch_repository.dart';
import 'package:yemen_gate_attendance_app/app/data/repositories/scheduling_repository.dart';
import 'package:yemen_gate_attendance_app/app/themes/app_colors.dart';
import 'package:yemen_gate_attendance_app/app/views/widgets/shift_schedule_cell.dart';
import 'package:yemen_gate_attendance_app/core/services/token_storage.dart';

class _MockSchedulingRepository extends Mock implements SchedulingRepository {}

class _MockBranchRepository extends Mock implements BranchRepository {}

class _MockTokenStorage extends Mock implements TokenStorage {}

BoardDay _day({
  required ShiftStatus status,
  List<String> conflicts = const [],
}) {
  return BoardDay(
    date: DateTime(2026, 6, 23),
    status: status,
    templateName: status == ShiftStatus.assigned ? 'Day' : null,
    shiftStart: status == ShiftStatus.assigned ? '09:00:00' : null,
    shiftEnd: status == ShiftStatus.assigned ? '17:00:00' : null,
    conflicts: conflicts,
    isWorkingToday: false,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2020));
    registerFallbackValue(ShiftStatus.assigned);
  });

  group('ShiftScheduleCell', () {
    testWidgets('renders Off label for day off status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiftScheduleCell(day: _day(status: ShiftStatus.dayOff)),
          ),
        ),
      );

      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('renders Leave label for on leave status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiftScheduleCell(day: _day(status: ShiftStatus.onLeave)),
          ),
        ),
      );

      expect(find.text('Leave'), findsOneWidget);
    });

    testWidgets('shows conflict badge when conflicts are present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiftScheduleCell(
              day: _day(
                status: ShiftStatus.assigned,
                conflicts: const ['leave_vs_assignment'],
              ),
              templateColor: AppColors.primary,
            ),
          ),
        ),
      );

      expect(find.text('!'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
    });
  });

  group('ShiftScheduleController week navigation', () {
    late _MockSchedulingRepository schedulingRepository;
    late _MockBranchRepository branchRepository;
    late _MockTokenStorage tokenStorage;
    late ShiftScheduleController controller;

    setUp(() {
      Get.testMode = true;
      schedulingRepository = _MockSchedulingRepository();
      branchRepository = _MockBranchRepository();
      tokenStorage = _MockTokenStorage();

      when(() => tokenStorage.canViewSchedule).thenReturn(true);
      when(() => tokenStorage.canManageSchedule).thenReturn(false);
      when(() => tokenStorage.branchId).thenReturn('branch-1');
      when(() => branchRepository.listBranches()).thenAnswer((_) async => []);

      controller = ShiftScheduleController(
        schedulingRepository: schedulingRepository,
        branchRepository: branchRepository,
        tokenStorage: tokenStorage,
      );
    });

    tearDown(() {
      Get.reset();
    });

    test('weekDates returns seven days from board range', () {
      final start = DateTime(2026, 6, 23);
      controller.board.value = ScheduleBoard(
        branchId: 'branch-1',
        startDate: start,
        endDate: start.add(const Duration(days: 6)),
        templates: const [],
        employees: const [],
        meta: const BoardMeta(
          assignedCount: 0,
          unassignedCount: 0,
          onLeaveCount: 0,
          dayOffCount: 0,
          conflictCount: 0,
        ),
      );

      expect(controller.weekDates, hasLength(7));
      expect(controller.weekDates.first, start);
    });

    testWidgets('refreshBoard week view uses monday through sunday query range',
        (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));

      final weekStart = DateTime(2026, 6, 23);
      controller.selectedBranchId.value = 'branch-1';
      controller.weekStart.value = weekStart;
      controller.isTodayView.value = false;
      controller.canViewSchedule.value = true;

      when(
        () => schedulingRepository.getBoard(
          branchId: any(named: 'branchId'),
          start: any(named: 'start'),
          end: any(named: 'end'),
          status: any(named: 'status'),
        ),
      ).thenAnswer(
        (_) async => ScheduleBoard(
          branchId: 'branch-1',
          startDate: weekStart,
          endDate: sundayOfWeek(weekStart),
          templates: const [],
          employees: const [
            BoardEmployee(
              employeeId: 'e1',
              fullName: 'Jane',
              employeeCode: 'EMP-01',
              isActive: true,
              days: [],
            ),
          ],
          meta: const BoardMeta(
            assignedCount: 1,
            unassignedCount: 0,
            onLeaveCount: 0,
            dayOffCount: 0,
            conflictCount: 0,
          ),
        ),
      );

      when(
        () => schedulingRepository.getTemplates(branchId: any(named: 'branchId')),
      ).thenAnswer((_) async => []);

      await controller.refreshBoard();

      verify(
        () => schedulingRepository.getBoard(
          branchId: 'branch-1',
          start: weekStart,
          end: sundayOfWeek(weekStart),
          status: null,
        ),
      ).called(1);
    });
  });
}
