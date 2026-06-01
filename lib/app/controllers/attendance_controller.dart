import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../data/datasources/remote/attendance_remote_datasource.dart';
import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/models/attendance/attendance_error_model.dart';
import '../data/models/auth/auth_error_model.dart';
import '../data/models/attendance/attendance_request_model.dart';
import '../data/models/attendance/employee_model.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../utils/employee_clock_status.dart';
import '../views/widgets/attendance_pin_dialog.dart';
import '../views/widgets/set_pin_dialog.dart';

enum AttendanceDialogAction { clockIn, clockOut }

enum _AttendanceDialogResult { completed, cancelled }

class AttendanceController extends GetxController {
  AttendanceController({
    required AttendanceRepository repository,
    required AuthRepository authRepository,
  }) : _repository = repository,
       _authRepository = authRepository;

  final AttendanceRepository _repository;
  final AuthRepository _authRepository;

  final scrollController = ScrollController();
  final pinConfirmController = TextEditingController();

  static const int _pageSize = 12;

  final employeesLoading = true.obs;
  final allEmployees = <EmployeeModel>[].obs;
  final visibleCount = 0.obs;

  final Rxn<EmployeeModel> dialogEmployee = Rxn<EmployeeModel>();
  final dialogAction = Rxn<AttendanceDialogAction>();
  final dialogError = ''.obs;
  final isVerifying = false.obs;
  final dialogSubmitting = false.obs;
  final elapsedTicker = 0.obs;

  Timer? _elapsedTimer;

  bool get hasMore => visibleCount.value < allEmployees.length;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    pinConfirmController.addListener(_clearDialogErrorOnPinChange);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedTicker.value++;
    });
    _loadEmployees();
  }

  void _clearDialogErrorOnPinChange() {
    if (dialogError.value.isNotEmpty &&
        pinConfirmController.text.isNotEmpty) {
      dialogError.value = '';
    }
  }

  Future<void> _loadEmployees() async {
    employeesLoading.value = true;
    try {
      final list = await _repository.fetchEmployees();
      allEmployees.assignAll(list);
      _resetVisibleWindow();
    } on AttendanceErrorModel {
      Get.offAllNamed(AppRoutes.login);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return;
      Get.offAllNamed(AppRoutes.login);
    } catch (_) {
      Get.offAllNamed(AppRoutes.login);
    } finally {
      employeesLoading.value = false;
    }
  }

  void _resetVisibleWindow() {
    if (allEmployees.isEmpty) {
      visibleCount.value = 0;
      return;
    }
    visibleCount.value =
        allEmployees.length < _pageSize ? allEmployees.length : _pageSize;
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    if (!hasMore) return;
    final pos = scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      loadMoreEmployees();
    }
  }

  void loadMoreEmployees() {
    if (!hasMore) return;
    final next = visibleCount.value + _pageSize;
    visibleCount.value =
        next > allEmployees.length ? allEmployees.length : next;
  }

  Future<void> openAttendanceDialog(
    EmployeeModel employee,
    AttendanceDialogAction action,
  ) async {
    dialogEmployee.value = employee;
    dialogAction.value = action;
    dialogError.value = '';
    pinConfirmController.clear();
    final result = await Get.dialog<_AttendanceDialogResult>(
      const AttendancePinDialog(),
      barrierDismissible: false,
    );

    if (result == _AttendanceDialogResult.completed) {
      await refreshEmployees();
    }
  }

  void cancelAttendanceDialog() {
    Get.back(result: _AttendanceDialogResult.cancelled);
    dialogError.value = '';
    pinConfirmController.clear();
  }

  Future<void> refreshEmployees() async {
    await _loadEmployees();
  }

  Future<void> submitAttendanceDialog() async {
    final pin = pinConfirmController.text.trim();
    if (pin.length != 4) {
      dialogError.value = 'Please enter your 4-digit PIN';
      return;
    }

    final emp = dialogEmployee.value;
    final action = dialogAction.value;
    if (emp == null || action == null) return;

    isVerifying.value = true;
    dialogError.value = '';
    try {
      final verifyResult = await _authRepository.verifyPin(
        emp.id,
        pin,
      );
      if (verifyResult.pinNotSet) {
        isVerifying.value = false;
        await _promptSetPinForEmployee(emp, action);
        return;
      }
      if (!verifyResult.matched) {
        dialogError.value = 'Incorrect PIN. Please try again.';
        return;
      }
    } on AuthErrorModel catch (e) {
      dialogError.value = e.detail;
      return;
    } on DioException catch (e) {
      final parsed = parseAuthError(e);
      dialogError.value =
          parsed?.detail ?? e.message ?? 'Unable to verify. Please try again.';
      return;
    } catch (e) {
      dialogError.value = e.toString();
      return;
    } finally {
      isVerifying.value = false;
    }

    await _performClockAction(emp, action);
  }

  Future<void> _promptSetPinForEmployee(
    EmployeeModel emp,
    AttendanceDialogAction action,
  ) async {
    final newPin = await Get.dialog<String>(
      SetPinDialog(
        employeeName: emp.fullName,
        employeePhone: emp.phone,
        title: 'Create your PIN',
        subtitle: 'Set a 4-digit PIN for clock-in and clock-out.',
        submitLabel: action == AttendanceDialogAction.clockIn
            ? 'Save & Clock In'
            : 'Save & Clock Out',
        onSubmit: (pin, confirmPin) async {
          await _authRepository.setPin(
            employeeId: emp.id,
            pin: pin,
            confirmPin: confirmPin,
          );
          return true;
        },
      ),
      barrierDismissible: false,
    );
    if (newPin == null || newPin.length != 4) return;

    final succeeded = await _performClockAction(
      emp,
      action,
      closeDialogOnSuccess: true,
    );
    if (succeeded) {
      await refreshEmployees();
    }
  }

  Future<bool> _performClockAction(
    EmployeeModel emp,
    AttendanceDialogAction action, {
    bool closeDialogOnSuccess = true,
  }) async {
    dialogSubmitting.value = true;
    try {
      final position = await _determinePosition();
      final body = AttendanceRequestModel(
        employeeId: emp.id,
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
      );

      if (action == AttendanceDialogAction.clockIn) {
        await _repository.clockIn(body);
        if (closeDialogOnSuccess) {
          Get.back(result: _AttendanceDialogResult.completed);
        }
        pinConfirmController.clear();
        Get.snackbar(
          'Success',
          'Clock-in recorded successfully',
          backgroundColor: Colors.green,
        );
      } else {
        await _repository.clockOut(body);
        if (closeDialogOnSuccess) {
          Get.back(result: _AttendanceDialogResult.completed);
        }
        pinConfirmController.clear();
        Get.snackbar(
          'Success',
          'Clock-out recorded successfully',
          backgroundColor: Colors.green,
        );
      }
      return true;
    } on AttendanceErrorModel catch (e) {
      dialogError.value = e.detail;
    } on DioException catch (e) {
      final parsed = parseAttendanceError(e);
      dialogError.value = parsed?.detail ?? e.message ?? 'Request failed';
    } catch (e) {
      dialogError.value = e.toString();
    } finally {
      dialogSubmitting.value = false;
    }
    return false;
  }

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable them.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Please enable it from settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  String formatClockedInDuration(EmployeeModel employee) {
    elapsedTicker.value;
    return formatEmployeeClockDuration(employee);
  }

  @override
  void onClose() {
    _elapsedTimer?.cancel();
    scrollController.removeListener(_onScroll);
    pinConfirmController.removeListener(_clearDialogErrorOnPinChange);
    scrollController.dispose();
    pinConfirmController.dispose();
    super.onClose();
  }
}
