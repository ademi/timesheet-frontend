import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/token_storage.dart';
import '../data/models/branch/branch_model.dart';
import '../data/models/scheduling/board_day.dart';
import '../data/models/scheduling/board_employee.dart';
import '../data/models/scheduling/assignment_models.dart';
import '../data/models/scheduling/copy_week_models.dart';
import '../data/models/scheduling/employee_schedule_models.dart';
import '../data/models/scheduling/leave_models.dart';
import '../data/models/scheduling/schedule_board.dart';
import '../data/models/scheduling/schedule_template.dart';
import '../data/models/scheduling/scheduling_date_utils.dart';
import '../data/models/scheduling/shift_status.dart';
import '../data/repositories/branch_repository.dart';
import '../data/repositories/scheduling_repository.dart';
import '../themes/app_colors.dart';
import '../views/widgets/shift_schedule_cell_sheet.dart';
import '../views/widgets/shift_schedule_manage_dialogs.dart';
import '../views/widgets/shift_schedule_utils.dart';

class ShiftScheduleController extends GetxController {
  ShiftScheduleController({
    required SchedulingRepository schedulingRepository,
    required BranchRepository branchRepository,
    required TokenStorage tokenStorage,
  })  : _schedulingRepository = schedulingRepository,
        _branchRepository = branchRepository,
        _tokenStorage = tokenStorage;

  final SchedulingRepository _schedulingRepository;
  final BranchRepository _branchRepository;
  final TokenStorage _tokenStorage;

  final selectedBranchId = RxnString();
  final weekStart = Rx<DateTime>(mondayOfWeek(DateTime.now()));
  final isTodayView = true.obs;
  final statusFilter = Rxn<ShiftStatus>();
  final board = Rxn<ScheduleBoard>();
  final branches = <BranchModel>[].obs;
  final isLoading = false.obs;
  final canViewSchedule = false.obs;
  final canManageSchedule = false.obs;
  final isAccessDenied = false.obs;
  final conflictFilterOnly = false.obs;
  final isSaving = false.obs;
  final cachedTemplates = <ScheduleTemplate>[].obs;

  Timer? _weekNavDebounce;

  @override
  void onClose() {
    _weekNavDebounce?.cancel();
    super.onClose();
  }
  @override
  void onInit() {
    super.onInit();
    loadPermissions();
    selectedBranchId.value = _tokenStorage.branchId;
    _loadBranches();
    refreshBoard();
  }

  void loadPermissions() {
    canViewSchedule.value = _tokenStorage.canViewSchedule;
    canManageSchedule.value = _tokenStorage.canManageSchedule;
    if (!canViewSchedule.value) {
      isAccessDenied.value = true;
    }
  }

  Future<void> _loadBranches() async {
    try {
      branches.assignAll(await _branchRepository.listBranches());
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e), retryAction: _loadBranches);
    }
  }

  Future<void> selectBranch(String branchId) async {
    selectedBranchId.value = branchId;
    final branch = branches.firstWhereOrNull((b) => b.id == branchId);
    if (branch != null) {
      await _tokenStorage.persistBranchSelection(
        branchId: branch.id,
        branchName: branch.name,
      );
    } else {
      await _tokenStorage.persistBranchId(branchId);
    }
    await refreshBoard();
  }

  Future<void> toggleView({required bool today}) async {
    isTodayView.value = today;
    await refreshBoard();
  }

  Future<void> goToPreviousWeek() async {
    weekStart.value = weekStart.value.subtract(const Duration(days: 7));
    _scheduleWeekRefresh();
  }

  Future<void> goToNextWeek() async {
    weekStart.value = weekStart.value.add(const Duration(days: 7));
    _scheduleWeekRefresh();
  }

  Future<void> goToToday() async {
    weekStart.value = mondayOfWeek(DateTime.now());
    isTodayView.value = true;
    await refreshBoard();
  }

  Future<void> applyStatusFilter(ShiftStatus? status) async {
    statusFilter.value = status;
    conflictFilterOnly.value = false;
    await refreshBoard();
  }

  void toggleConflictFilter() {
    conflictFilterOnly.toggle();
    if (conflictFilterOnly.value) {
      statusFilter.value = null;
    }
  }

  void _scheduleWeekRefresh() {
    if (isTodayView.value) return;
    _weekNavDebounce?.cancel();
    _weekNavDebounce = Timer(const Duration(milliseconds: 300), () {
      refreshBoard();
    });
  }

  Future<void> refreshBoard() async {
    loadPermissions();
    if (!canViewSchedule.value) {
      board.value = null;
      isAccessDenied.value = true;
      return;
    }

    final branchId = selectedBranchId.value;
    if (branchId == null || branchId.isEmpty) {
      _showError('Select a branch to view the shift schedule.');
      return;
    }

    try {
      isLoading.value = true;
      isAccessDenied.value = false;

      final filter = statusFilter.value;
      if (isTodayView.value) {
        board.value = await _schedulingRepository.getBoardToday(
          branchId: branchId,
          status: filter,
        );
      } else {
        final start = weekStart.value;
        final end = sundayOfWeek(start);
        board.value = await _schedulingRepository.getBoard(
          branchId: branchId,
          start: start,
          end: end,
          status: filter,
        );
      }
      await _syncTemplatesCache();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        board.value = null;
        isAccessDenied.value = true;
        return;
      }
      if (e.response?.statusCode == 404) {
        board.value = null;
        _showError(
          _extractErrorMessage(e),
          retryAction: () async {
            await _loadBranches();
            await refreshBoard();
          },
        );
        return;
      }
      _showError(_extractErrorMessage(e), retryAction: refreshBoard);
    } catch (_) {
      _showError(
        'Failed to load shift schedule.',
        retryAction: refreshBoard,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void openCellDetail(BoardEmployee employee, BoardDay day) {
    ShiftScheduleCellSheet.show(
      employee: employee,
      day: day,
      canManage: canManageSchedule.value,
      controller: this,
    );
  }

  List<ScheduleTemplate> get activeTemplates => cachedTemplates;

  Future<void> _syncTemplatesCache() async {
    final fromBoard = board.value?.templates ?? [];
    if (fromBoard.isNotEmpty) {
      cachedTemplates.assignAll(fromBoard.where((t) => t.isActive));
      return;
    }

    final branchId = selectedBranchId.value;
    if (branchId == null || branchId.isEmpty) return;

    try {
      final templates =
          await _schedulingRepository.getTemplates(branchId: branchId);
      cachedTemplates.assignAll(templates.where((t) => t.isActive));
    } on DioException catch (_) {
      // Board templates are preferred; API fallback is best-effort.
    }
  }

  void invalidateTemplatesCache() {
    cachedTemplates.clear();
  }

  void openFabMenu() {
    Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_all_rounded, color: AppColors.primary),
              title: const Text('Copy last week'),
              subtitle: const Text('Copy overrides to current week'),
              onTap: () {
                Get.back();
                copyLastWeek();
              },
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  Future<void> changeShiftOverride({
    required BoardEmployee employee,
    required BoardDay day,
  }) async {
    final templateId = await showShiftTemplatePicker(
      templates: activeTemplates.toList(),
    );
    if (templateId == null) return;

    final ok = await _runWrite(
      () => _schedulingRepository.upsertAssignment(
        AssignmentUpsertRequest(
          employeeId: employee.employeeId,
          workDate: day.date,
          templateId: templateId,
        ),
      ),
      successMessage: 'Shift updated.',
    );
    if (ok) Get.back();
  }

  Future<void> markDayOff({
    required BoardEmployee employee,
    required BoardDay day,
  }) async {
    final confirmed = await showSchedulingConfirmDialog(
      title: 'Mark day off',
      message:
          'Mark ${employee.fullName} as off on ${fmtSchedulingDateDisplay(day.date)}?',
    );
    if (!confirmed) return;

    final ok = await _runWrite(
      () => _schedulingRepository.upsertAssignment(
        AssignmentUpsertRequest(
          employeeId: employee.employeeId,
          workDate: day.date,
          isDayOff: true,
        ),
      ),
      successMessage: 'Day marked off.',
    );
    if (ok) Get.back();
  }

  Future<void> markLeave({
    required BoardEmployee employee,
    required BoardDay day,
  }) async {
    final input = await showLeaveDialog(initialDate: day.date);
    if (input == null) return;

    final ok = await _runWrite(
      () => _schedulingRepository.createLeave(
        LeaveCreateRequest(
          employeeId: employee.employeeId,
          startDate: input.start,
          endDate: input.end,
          leaveType: input.leaveType,
        ),
      ),
      successMessage: 'Leave recorded.',
    );
    if (ok) Get.back();
  }

  Future<void> clearOverride({
    required BoardEmployee employee,
    required BoardDay day,
  }) async {
    final branchId = selectedBranchId.value;
    if (branchId == null || branchId.isEmpty) return;

    final confirmed = await showSchedulingConfirmDialog(
      title: 'Clear override',
      message: 'Revert this day to the recurring schedule?',
    );
    if (!confirmed) return;

    final ok = await _runWrite(() async {
      final assignments = await _schedulingRepository.listAssignments(
        start: day.date,
        end: day.date,
        branchId: branchId,
      );
      final match = assignments
          .where((a) => a.employeeId == employee.employeeId)
          .firstOrNull;
      if (match == null) {
        throw DioException(
          requestOptions: RequestOptions(path: '/assignments'),
          message: 'No override found for this day.',
        );
      }
      await _schedulingRepository.deleteAssignment(match.id);
    }, successMessage: 'Override cleared.');
    if (ok) Get.back();
  }

  Future<void> openRecurringSchedules(BoardEmployee employee) async {
    try {
      isSaving.value = true;
      final schedules = await _schedulingRepository.listEmployeeSchedules(
        employeeId: employee.employeeId,
      );
      await Get.bottomSheet(
        RecurringSchedulesSheet(
          employee: employee,
          schedules: schedules,
          templates: activeTemplates.toList(),
          onCreate: () async {
            Get.back();
            await createRecurringSchedule(employee);
          },
          onDelete: (scheduleId) async {
            Get.back();
            await deleteRecurringSchedule(scheduleId);
          },
        ),
        isScrollControlled: true,
        backgroundColor: AppColors.cardBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      );
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> createRecurringSchedule(BoardEmployee employee) async {
    final input = await showRecurringScheduleDialog(
      templates: activeTemplates.toList(),
      initialStart: DateTime.now(),
    );
    if (input == null) return;

    await _runWrite(
      () => _schedulingRepository.createEmployeeSchedule(
        EmployeeScheduleCreateRequest(
          employeeId: employee.employeeId,
          templateId: input.templateId,
          startDate: input.startDate,
          endDate: input.endDate,
        ),
      ),
      successMessage: 'Recurring schedule created.',
    );
  }

  Future<void> deleteRecurringSchedule(String scheduleId) async {
    final confirmed = await showSchedulingConfirmDialog(
      title: 'Delete recurring schedule',
      message: 'Remove this recurring shift pattern?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    await _runWrite(
      () => _schedulingRepository.deleteEmployeeSchedule(scheduleId),
      successMessage: 'Recurring schedule deleted.',
    );
  }

  Future<void> copyLastWeek() async {
    final branchId = selectedBranchId.value;
    if (branchId == null || branchId.isEmpty) return;

    final targetStart = isTodayView.value
        ? mondayOfWeek(DateTime.now())
        : weekStart.value;
    final sourceStart = targetStart.subtract(const Duration(days: 7));

    final confirmed = await showSchedulingConfirmDialog(
      title: 'Copy last week',
      message:
          'Copy daily overrides from ${formatWeekRangeLabel(sourceStart)} '
          'to ${formatWeekRangeLabel(targetStart)}?',
    );
    if (!confirmed) return;

    await _runWrite(
      () => _schedulingRepository.copyWeek(
        CopyWeekRequest(
          branchId: branchId,
          sourceStart: sourceStart,
          targetStart: targetStart,
          mode: 'overrides_only',
        ),
      ),
      successMessage: 'Week copied successfully.',
    );
  }

  Future<bool> _runWrite(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    try {
      isSaving.value = true;
      await action();
      await refreshBoard();
      _showSuccess(successMessage);
      return true;
    } on DioException catch (e) {
      await _handleWriteError(e);
      return false;
    } catch (e) {
      _showError(e.toString());
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _handleWriteError(DioException e) async {
    final status = e.response?.statusCode;
    final message = _extractErrorMessage(e);
    if (status == 409) {
      await Get.dialog<void>(
        AlertDialog(
          title: const Text('Conflict'),
          content: Text(message),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    _showError(message);
  }

  void _showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: AppColors.textDark,
    );
  }

  /// Employees visible in week view (after client-side conflict filter).
  List<BoardEmployee> get weekEmployees {
    final list = board.value?.employees ?? [];
    if (!conflictFilterOnly.value) return list;
    return list
        .where((e) => e.days.any((d) => d.conflicts.isNotEmpty))
        .toList();
  }

  List<DateTime> get weekDates {
    final schedule = board.value;
    if (schedule == null) return const [];

    final dates = <DateTime>[];
    var current = DateTime(
      schedule.startDate.year,
      schedule.startDate.month,
      schedule.startDate.day,
    );
    final end = DateTime(
      schedule.endDate.year,
      schedule.endDate.month,
      schedule.endDate.day,
    );
    while (!current.isAfter(end)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  BoardDay? dayForEmployee(BoardEmployee employee, DateTime date) {
    for (final day in employee.days) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }

  bool isTodayDate(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Employees visible in today view (after client-side conflict filter).
  List<BoardEmployee> get todayEmployees {
    final list = board.value?.employees ?? [];
    if (!conflictFilterOnly.value) return list;
    return list
        .where((e) {
          final day = todayDayFor(e);
          return day != null && day.conflicts.isNotEmpty;
        })
        .toList();
  }

  BoardDay? todayDayFor(BoardEmployee employee) {
    for (final day in employee.days) {
      if (day.isWorkingToday) return day;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final day in employee.days) {
      if (day.date.year == today.year &&
          day.date.month == today.month &&
          day.date.day == today.day) {
        return day;
      }
    }
    return employee.days.isNotEmpty ? employee.days.first : null;
  }

  Color? colorForTemplate(String? templateId) {
    if (templateId == null || templateId.isEmpty) return null;
    final templates = [
      ...cachedTemplates,
      ...?board.value?.templates,
    ];
    for (final template in templates) {
      if (template.id == templateId) {
        return parseSchedulingColor(template.color);
      }
    }
    return null;
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.statusCode == 403) {
      return 'You do not have permission to view the shift schedule.';
    }
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List) {
        final messages = detail
            .map((item) {
              if (item is Map && item['msg'] is String) {
                return item['msg'] as String;
              }
              return item?.toString() ?? '';
            })
            .where((m) => m.isNotEmpty)
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }
    }
    return e.message ?? 'Unable to load shift schedule.';
  }

  void _showError(String message, {Future<void> Function()? retryAction}) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
      duration: const Duration(seconds: 5),
      mainButton: retryAction == null
          ? null
          : TextButton(
              onPressed: () {
                if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
                retryAction();
              },
              child: const Text(
                'Retry',
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
    );
  }
}
