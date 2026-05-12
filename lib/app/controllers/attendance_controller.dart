import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../data/datasources/remote/attendance_remote_datasource.dart';
import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/models/attendance/attendance_error_model.dart';
import '../data/models/auth/auth_error_model.dart';
import '../data/models/attendance/attendance_request_model.dart';
import '../data/models/attendance/employee_model.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../views/widgets/attendance_password_dialog.dart';
import '../views/widgets/change_password_dialog.dart';

enum AttendanceDialogAction { clockIn, clockOut }

enum _AttendanceDialogResult { completed, passwordChangeRequired, cancelled }

class AttendanceController extends GetxController {
  AttendanceController({
    required AttendanceRepository repository,
    required AuthRepository authRepository,
  }) : _repository = repository,
       _authRepository = authRepository;

  final AttendanceRepository _repository;
  final AuthRepository _authRepository;

  final scrollController = ScrollController();
  final passwordConfirmController = TextEditingController();

  // Change-password dialog controllers
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  static const int _pageSize = 12;
  static const String _defaultPassword = '123456';

  final employeesLoading = true.obs;
  final allEmployees = <EmployeeModel>[].obs;
  final visibleCount = 0.obs;

  final Rxn<EmployeeModel> dialogEmployee = Rxn<EmployeeModel>();
  final dialogAction = Rxn<AttendanceDialogAction>();
  final dialogError = ''.obs;
  final isVerifying = false.obs;
  final dialogSubmitting = false.obs;

  // Change-password state
  final changePasswordError = ''.obs;
  final isChangingPassword = false.obs;

  bool get hasMore => visibleCount.value < allEmployees.length;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    passwordConfirmController.addListener(_clearDialogErrorOnPasswordChange);
    _loadEmployees();
  }

  void _clearDialogErrorOnPasswordChange() {
    if (dialogError.value.isNotEmpty) {
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
    passwordConfirmController.clear();
    final result = await Get.dialog<_AttendanceDialogResult>(
      const AttendancePasswordDialog(),
      barrierDismissible: false,
    );

    if (result == _AttendanceDialogResult.passwordChangeRequired) {
      changePasswordError.value = '';
      newPasswordController.clear();
      confirmPasswordController.clear();
      final changed = await Get.dialog<bool>(
        const ChangePasswordDialog(),
        barrierDismissible: false,
      );
      if (changed == true) {
        await refreshEmployees();
      }
      return;
    }

    if (result == _AttendanceDialogResult.completed) {
      await refreshEmployees();
    }
  }

  void cancelAttendanceDialog() {
    Get.back(result: _AttendanceDialogResult.cancelled);
    dialogError.value = '';
    passwordConfirmController.clear();
  }

  Future<void> refreshEmployees() async {
    await _loadEmployees();
  }

  Future<void> submitAttendanceDialog() async {
    final pwd = passwordConfirmController.text.trim();
    if (pwd.isEmpty) {
      dialogError.value = 'Please enter your password to confirm';
      return;
    }

    final emp = dialogEmployee.value;
    final action = dialogAction.value;
    if (emp == null || action == null) return;

    isVerifying.value = true;
    dialogError.value = '';
    try {
      final verifyResult = await _authRepository.verifyUser(
        emp.email.trim(),
        pwd,
      );
      if (!verifyResult.matched) {
        dialogError.value = 'Verification failed. Please try again.';
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

    // ── Intercept default password for clock-in only ──
    if (action == AttendanceDialogAction.clockIn && pwd == _defaultPassword) {
      Get.back(result: _AttendanceDialogResult.passwordChangeRequired);
      passwordConfirmController.clear();
      return;
    }

    await _performClockAction(emp, action);
  }

  /// Submits the change-password form, then auto-proceeds with clock-in.
  Future<void> submitChangePassword() async {
    final newPwd = newPasswordController.text.trim();
    final confirmPwd = confirmPasswordController.text.trim();

    if (newPwd.isEmpty || confirmPwd.isEmpty) {
      changePasswordError.value = 'Both fields are required';
      return;
    }
    if (newPwd != confirmPwd) {
      changePasswordError.value = 'Passwords do not match';
      return;
    }
    if (newPwd == _defaultPassword) {
      changePasswordError.value =
          'New password cannot be the same as the default password';
      return;
    }

    final emp = dialogEmployee.value;
    if (emp == null) return;

    isChangingPassword.value = true;
    changePasswordError.value = '';
    try {
      await _authRepository.changePassword(
        emp.email.trim(),
        _defaultPassword,
        newPwd,
      );
    } on AuthErrorModel catch (e) {
      changePasswordError.value = e.detail;
      return;
    } on DioException catch (e) {
      final parsed = parseAuthError(e);
      changePasswordError.value =
          parsed?.detail ?? e.message ?? 'Failed to change password';
      return;
    } catch (e) {
      changePasswordError.value = e.toString();
      return;
    } finally {
      isChangingPassword.value = false;
    }

    final clockInSucceeded = await _performClockAction(
      emp,
      AttendanceDialogAction.clockIn,
      closeDialogOnSuccess: false,
    );
    if (clockInSucceeded) {
      Get.back(result: true);
      newPasswordController.clear();
      confirmPasswordController.clear();

      Get.snackbar(
        'Password Changed',
        'Your password has been updated successfully',
        backgroundColor: Colors.green,
      );
      return;
    }

    if (dialogError.value.isNotEmpty) {
      changePasswordError.value = dialogError.value;
      dialogError.value = '';
    }
  }

  /// Shared helper that executes the actual clock-in / clock-out API call.
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
        passwordConfirmController.clear();
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
        passwordConfirmController.clear();
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

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    passwordConfirmController.removeListener(_clearDialogErrorOnPasswordChange);
    scrollController.dispose();
    passwordConfirmController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
