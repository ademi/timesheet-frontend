import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../credentials/data/models/credential_models.dart';
import '../../credentials/data/repositories/credentials_repository.dart';
import '../data/models/engagement_models.dart';
import '../data/repositories/engagements_repository.dart';
import '../utils/missing_categories.dart';

class WorkforceController extends GetxController {
  WorkforceController({
    required EngagementsRepository repository,
    required CredentialsRepository credentialsRepository,
    required SessionService session,
  }) : _repository = repository,
       _credentialsRepository = credentialsRepository,
       _session = session;

  final EngagementsRepository _repository;
  final CredentialsRepository _credentialsRepository;
  final SessionService _session;

  final items = <EngagementOut>[].obs;
  final statusFilter = RxnString();
  final missingDocsFilter = false.obs;
  final credentialsByContractor = <String, List<CredentialOut>>{}.obs;
  final isLoadingCredentials = false.obs;
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
  bool get canRead => _session.hasPermission(AppPermissions.contractorsRead);

  List<EngagementOut> get filtered {
    var list = items.toList();
    final f = statusFilter.value;
    if (f != null && f.isNotEmpty) {
      list = list.where((e) => e.status == f).toList();
    }
    if (missingDocsFilter.value) {
      list = list.where(hasMissingRequiredDocs).toList();
    }
    return list;
  }

  bool hasMissingRequiredDocs(EngagementOut engagement) =>
      missingCategories(
        engagement,
        credentialsByContractor[engagement.contractorId] ?? const [],
      ).isNotEmpty;

  Future<void> setMissingDocsFilter(bool value) async {
    missingDocsFilter.value = value;
    if (value) {
      await _ensureCredentialsLoaded();
    }
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
      if (missingDocsFilter.value) {
        credentialsByContractor.clear();
        await _ensureCredentialsLoaded();
      }
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
      final result = await _repository.invite(
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
        result.isRegistrationInvite
            ? 'Registration email sent'
            : 'Engagement created',
        result.isRegistrationInvite
            ? 'The contractor can register using the link in their email.'
            : 'Engagement created for this provider.',
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

  Future<void> runAction(String action, EngagementOut engagement) async {
    isSaving.value = true;
    errorMessage.value = null;
    eligibilityReasons.clear();
    try {
      final updated = await switch (action) {
        'approve' => _repository.approve(engagement.id),
        'activate' => _repository.activate(engagement.id),
        'approve_and_activate' => _repository.approveAndActivate(engagement.id),
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

  Future<void> _ensureCredentialsLoaded() async {
    final engagementByContractor = <String, EngagementOut>{};
    for (final engagement in items) {
      engagementByContractor.putIfAbsent(
        engagement.contractorId,
        () => engagement,
      );
    }
    final pending =
        engagementByContractor.entries
            .where((e) => !credentialsByContractor.containsKey(e.key))
            .toList();
    if (pending.isEmpty) return;

    isLoadingCredentials.value = true;
    try {
      final results = await Future.wait(
        pending.map(
          (entry) => _credentialsRepository.listForTenantContractor(
            entry.key,
            engagementId: entry.value.id,
          ),
        ),
      );
      for (var i = 0; i < pending.length; i++) {
        credentialsByContractor[pending[i].key] = results[i];
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingCredentials.value = false;
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
