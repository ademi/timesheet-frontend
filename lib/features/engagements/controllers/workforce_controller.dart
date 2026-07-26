import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../data/models/engagement_models.dart';
import '../data/repositories/engagements_repository.dart';

class WorkforceController extends GetxController {
  WorkforceController({
    required EngagementsRepository repository,
    required SessionService session,
  })  : _repository = repository,
        _session = session;

  final EngagementsRepository _repository;
  final SessionService _session;

  final items = <EngagementOut>[].obs;
  final statusFilter = RxnString();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final eligibilityReasons = <String>[].obs;

  // Invite form
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final selectedCategories = <String>{}.obs;

  EngagementOut? selected;

  bool get canInvite =>
      _session.hasPermission(AppPermissions.contractorsInvite);
  bool get canApprove =>
      _session.hasPermission(AppPermissions.contractorsApprove);
  bool get canManage =>
      _session.hasPermission(AppPermissions.contractorsManage);
  bool get canRead =>
      _session.hasPermission(AppPermissions.contractorsRead);

  List<EngagementOut> get filtered {
    final f = statusFilter.value;
    if (f == null || f.isEmpty) return items.toList();
    return items.where((e) => e.status == f).toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    phoneCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    if (!canRead) {
      errorMessage.value = 'Missing contractors.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repository.listTenantEngagements();
      items.assignAll(list);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void openDetail(EngagementOut e) {
    selected = e;
    eligibilityReasons.clear();
    errorMessage.value = null;
    Get.toNamed(AppRoutes.staffWorkforceDetail, arguments: e);
  }

  void toggleCategory(String category) {
    if (selectedCategories.contains(category)) {
      selectedCategories.remove(category);
    } else {
      selectedCategories.add(category);
    }
  }

  Future<void> submitInvite() async {
    if (!canInvite) {
      errorMessage.value = 'Missing contractors.invite permission.';
      return;
    }
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      errorMessage.value = 'Provide an email and/or phone.';
      return;
    }
    if (selectedCategories.isEmpty) {
      errorMessage.value = 'Select at least one required credential category.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.invite(
        EngagementInviteRequest(
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
          requiredCategories: selectedCategories.toList(),
        ),
      );
      emailCtrl.clear();
      phoneCtrl.clear();
      selectedCategories.clear();
      Get.back();
      Get.snackbar(
        'Invite sent',
        'Engagement created for this provider.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> runAction(
    String action,
    EngagementOut engagement,
  ) async {
    isSaving.value = true;
    errorMessage.value = null;
    eligibilityReasons.clear();
    try {
      final updated = await switch (action) {
        'approve' => _repository.approve(engagement.id),
        'activate' => _repository.activate(engagement.id),
        'approve_and_activate' =>
          _repository.approveAndActivate(engagement.id),
        'suspend' => _repository.suspend(engagement.id),
        'resume' => _repository.resume(engagement.id),
        'end' => _repository.end(engagement.id),
        _ => throw StateError('Unknown action $action'),
      };
      selected = updated;
      final idx = items.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        items[idx] = updated;
      } else {
        await load();
      }
      Get.snackbar(
        'Updated',
        'Engagement is now ${updated.status}.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (e.isEligibilityIncomplete) {
        eligibilityReasons.assignAll(e.eligibilityReasons);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  void openCredentialReview(EngagementOut engagement) {
    Get.toNamed(
      AppRoutes.staffCredentialReview,
      arguments: {
        'contractorId': engagement.contractorId,
        'engagementId': engagement.id,
      },
      parameters: {
        'contractorId': engagement.contractorId,
        'engagementId': engagement.id,
      },
    );
  }
}
