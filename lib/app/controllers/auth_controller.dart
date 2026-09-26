import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/auth/clear_session.dart';
import '../../core/network/must_change_password.dart';
import '../../core/services/session_service.dart';
import '../../features/billing/data/exported_visit_ids_store.dart';
import '../../features/billing/data/repositories/ndis_catalogue_repository.dart';
import '../../features/compliance_ops/bindings/compliance_ops_binding.dart';
import '../../features/contractor_onboarding/bindings/onboarding_binding.dart';
import '../../shared/widgets/app_toast.dart';
import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../services/push_notification_service.dart';

void _clearNdisCatalogueCacheIfRegistered() {
  if (Get.isRegistered<NdisCatalogueRepository>()) {
    Get.find<NdisCatalogueRepository>().clearCache();
  }
}

void _clearExportedVisitIdsIfRegistered() {
  if (Get.isRegistered<ExportedVisitIdsStore>()) {
    Get.find<ExportedVisitIdsStore>().clear();
  }
}

class AuthController extends GetxController {
  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;

  void togglePasswordVisibility() => isPasswordVisible.toggle();

  void _showError(String message) => AppToast.error('Error', message);

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final tokens = await _authRepository.loginWithTokens(
        emailController.text.trim(),
        passwordController.text,
      );
      if (Get.isRegistered<SessionService>()) {
        final session = Get.find<SessionService>();
        await session.applyAuthTokens(tokens);
        await session.hydrateFromMeContext();
      }
      if (Get.isRegistered<PushNotificationService>()) {
        await Get.find<PushNotificationService>().registerCurrentDeviceToken();
      }
      redirectToFirstLoginIfNeeded(
        mustChangePassword: tokens.mustChangePassword,
      );
      if (tokens.mustChangePassword) return;

      if (Get.isRegistered<SessionService>()) {
        final session = Get.find<SessionService>();
        Get.offAllNamed(session.resolvePostLoginRoute());
        return;
      }
      Get.offAllNamed(AppRoutes.adminBranchGateway);
    } on DioException catch (e) {
      if (isMustChangePasswordResponse(e)) {
        redirectToFirstLoginIfNeeded(mustChangePassword: true);
        return;
      }
      final parsed = parseAuthError(e);
      _showError(
        parsed?.detail ?? e.message ?? 'Network error. Please try again.',
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout({bool confirmDiscardOutbox = false}) async {
    final clockPending = hasPendingClockOutbox();
    final mediaPending = hasPendingMediaOutbox();
    final formPending = hasPendingFormDrafts();
    if (clockPending || mediaPending || formPending) {
      if (!confirmDiscardOutbox) {
        if (Get.testMode) {
          throw StateError(
            clockPending
                ? 'outbox_not_empty'
                : mediaPending
                    ? 'media_outbox_not_empty'
                    : 'form_draft_not_empty',
          );
        }
        final confirmed = await _confirmDiscardOutboxLogout(
          clockPending: clockPending,
          mediaPending: mediaPending,
          formPending: formPending,
        );
        if (!confirmed) return;
        confirmDiscardOutbox = true;
      }
      discardClockOutboxIfConfirmed(confirmDiscardOutbox: confirmDiscardOutbox);
      discardMediaOutboxIfConfirmed(confirmDiscardOutbox: confirmDiscardOutbox);
      discardFormDraftsIfConfirmed(confirmDiscardOutbox: confirmDiscardOutbox);
    }
    if (Get.isRegistered<PushNotificationService>()) {
      await Get.find<PushNotificationService>().unregisterCurrentDeviceToken();
    }
    if (Get.isRegistered<SessionService>()) {
      await Get.find<SessionService>().clear();
    }
    _clearNdisCatalogueCacheIfRegistered();
    _clearExportedVisitIdsIfRegistered();
    await _authRepository.logout();
    emailController.clear();
    passwordController.clear();
    Get.offAllNamed(AppRoutes.gateway);
    // After leaving any funnel route so dispose cannot re-ensure().
    OnboardingBinding.reset();
    HomeAlertsBinding.reset();
  }

  Future<bool> _confirmDiscardOutboxLogout({
    required bool clockPending,
    required bool mediaPending,
    required bool formPending,
  }) async {
    final parts = <String>[];
    if (clockPending) {
      parts.add('clock events waiting to sync');
    }
    if (mediaPending) {
      parts.add('photo/video evidence waiting to upload');
    }
    if (formPending) {
      parts.add('field notes waiting to sync');
    }
    final title = formPending && !clockPending && !mediaPending
        ? 'Unsent field notes'
        : mediaPending && !clockPending && !formPending
            ? 'Unsent evidence'
            : clockPending && !mediaPending && !formPending
                ? 'Unsent check-ins'
                : 'Unsent data';
    return await Get.dialog<bool>(
          AlertDialog(
            title: Text(title),
            content: Text(
              'You have ${parts.join(' and ')}. '
              'Logging out will discard them unless you wait for sync to finish.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Stay signed in'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Log out anyway'),
              ),
            ],
          ),
        ) ==
        true;
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
