import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../../shared/utils/name_sort.dart';
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
  final photosByContractor = <String, ProfilePhotoOut>{}.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final eligibilityReasons = <String>[].obs;
  final detailPhoto = Rxn<ProfilePhotoOut>();
  final isDetailPhotoLoading = false.obs;

  Timer? _errorClearTimer;
  static const _errorClearDelay = Duration(seconds: 8);

  // Invite form
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final selectedCategories = <String>{}.obs;
  final catalogCategories = <CredentialCategory>[].obs;
  final isLoadingCatalog = false.obs;
  final detailSelectedCategories = <String>{}.obs;
  final tabIndex = 0.obs;

  EngagementOut? selected;

  static const tabOverview = 0;
  static const tabCredentials = 1;
  static const tabVisits = 2;
  static const tabSchedule = 3;

  /// Invite multi-select options (catalog when loaded, else allowlist fallback).
  List<CredentialCategory> get inviteCategoryChoices {
    final choices = catalogCategories.isNotEmpty
        ? catalogCategories.toList()
        : credentialTypesAllowlist
            .map(
              (code) => CredentialCategory(
                code: code,
                label: credentialTypeLabel(code),
              ),
            )
            .toList();
    return sortedByName(choices, (c) => c.label);
  }

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
    list.sort((a, b) => compareNames(a.displayName, b.displayName));
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
    _errorClearTimer?.cancel();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    super.onClose();
  }

  void clearError() {
    _errorClearTimer?.cancel();
    _errorClearTimer = null;
    errorMessage.value = null;
    eligibilityReasons.clear();
  }

  void _setError(String message) {
    errorMessage.value = message;
    _errorClearTimer?.cancel();
    _errorClearTimer = Timer(_errorClearDelay, clearError);
  }

  Future<void> load() async {
    if (!canRead) {
      _setError('Missing contractors.read permission.');
      return;
    }
    isLoading.value = true;
    clearError();
    try {
      final list = await _repository.listTenantEngagements();
      items.assignAll(list);
      photosByContractor.clear();
      // Load avatars in the background so the list can render immediately.
      _ensureListPhotosLoaded();
      if (missingDocsFilter.value) {
        credentialsByContractor.clear();
        await _ensureCredentialsLoaded();
      }
    } on AppFailure catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  String? photoUrlFor(String contractorId) {
    final photo = photosByContractor[contractorId];
    if (photo == null || !photo.hasDisplayableUrl) return null;
    return photo.downloadUrl;
  }

  String? photoDocumentIdFor(String contractorId) =>
      photosByContractor[contractorId]?.documentId;

  void openDetail(EngagementOut e) {
    selected = e;
    tabIndex.value = tabOverview;
    clearError();
    detailPhoto.value = photosByContractor[e.contractorId];
    detailSelectedCategories
      ..clear()
      ..addAll(e.requiredDocCategories.map((c) => c.category));
    if (canManage && !e.isEnded) {
      loadCredentialCategories();
    }
    Get.toNamed(AppRoutes.staffWorkforceDetail, arguments: e);
    loadDetailProfilePhoto(e.contractorId);
  }

  Future<void> loadDetailProfilePhoto(String contractorId) async {
    if (contractorId.isEmpty || !canRead) return;
    isDetailPhotoLoading.value = true;
    try {
      detailPhoto.value =
          await _repository.getContractorProfilePhoto(contractorId);
    } on AppFailure {
      detailPhoto.value = null;
    } catch (_) {
      detailPhoto.value = null;
    } finally {
      isDetailPhotoLoading.value = false;
    }
  }

  void toggleCategory(String category) {
    if (selectedCategories.contains(category)) {
      selectedCategories.remove(category);
    } else {
      selectedCategories.add(category);
    }
  }

  void toggleDetailCategory(String category) {
    if (detailSelectedCategories.contains(category)) {
      detailSelectedCategories.remove(category);
    } else {
      detailSelectedCategories.add(category);
    }
  }

  Future<void> saveRequiredDocCategories(EngagementOut engagement) async {
    if (!canManage) {
      _setError('Missing contractors.manage permission.');
      return;
    }
    if (engagement.isEnded) {
      _setError('This worker is no longer in your workforce.');
      return;
    }
    if (detailSelectedCategories.isEmpty) {
      _setError('At least one required document category is required.');
      return;
    }
    isSaving.value = true;
    clearError();
    try {
      final updated = await _repository.replaceRequiredDocCategories(
        engagementId: engagement.id,
        categories: detailSelectedCategories.toList(),
      );
      selected = updated;
      final idx = items.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        items[idx] = updated;
      }
      detailSelectedCategories
        ..clear()
        ..addAll(updated.requiredDocCategories.map((c) => c.category));
    } on AppFailure catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> loadCredentialCategories() async {
    isLoadingCatalog.value = true;
    try {
      final list = await _credentialsRepository.listCredentialCategories();
      catalogCategories.assignAll(list);
    } on AppFailure {
      // Keep allowlist fallback via [inviteCategoryChoices].
    } catch (_) {
      // Keep allowlist fallback via [inviteCategoryChoices].
    } finally {
      isLoadingCatalog.value = false;
    }
  }

  Future<void> submitInvite() async {
    if (!canInvite) {
      _setError('Missing contractors.invite permission.');
      return;
    }
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      _setError('Provide an email and/or phone.');
      return;
    }
    if (selectedCategories.isEmpty) {
      _setError('Select at least one required document.');
      return;
    }

    isSaving.value = true;
    clearError();
    try {
      final preview = await _repository.previewInvite(
        EngagementInvitePreviewRequest(
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
        ),
      );
      if (preview.isBlocking) {
        _setError(preview.message);
        return;
      }

      var sendEmail = true;
      if (preview.needsRegistration) {
        final choice = await _confirmRegistrationInviteEmail(
          message: preview.message,
        );
        if (choice == null) return; // cancelled
        sendEmail = choice;
      }

      final result = await _repository.invite(
        EngagementInviteRequest(
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
          requiredCategories: selectedCategories.toList(),
          sendEmail: sendEmail,
        ),
      );
      emailCtrl.clear();
      phoneCtrl.clear();
      selectedCategories.clear();
      Get.back();
      final invite = result.registrationInvite;
      final inviteUrl = invite?.inviteUrl?.trim();
      if (result.isRegistrationInvite &&
          inviteUrl != null &&
          inviteUrl.isNotEmpty) {
        await _showRegistrationInviteLinkDialog(
          inviteUrl: inviteUrl,
          expiresAt: invite!.expiresAt,
          emailRequested: sendEmail,
        );
      } else {
        Get.snackbar(
          result.isRegistrationInvite ? 'Invite created' : 'Engagement created',
          result.isRegistrationInvite
              ? 'Share the registration link with the contractor.'
              : 'Engagement created for this provider.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          backgroundColor: AppColors.primary,
          colorText: AppColors.onPrimary,
        );
      }
      await load();
    } on AppFailure catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
    } finally {
      isSaving.value = false;
    }
  }

  /// Returns `true` to send email, `false` for link-only, `null` if cancelled.
  Future<bool?> _confirmRegistrationInviteEmail({
    required String message,
  }) async {
    return Get.dialog<bool>(
      AlertDialog(
        title: const Text('Contractor not in Rostiq'),
        content: Text(
          '$message\n\n'
          'Send an invitation email now? You can still copy a registration '
          'link either way.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Link only'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Send email'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _showRegistrationInviteLinkDialog({
    required String inviteUrl,
    required DateTime expiresAt,
    bool emailRequested = true,
  }) async {
    await Get.dialog<void>(
      AlertDialog(
        title: const Text('Invite created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emailRequested
                  ? 'An invitation email was requested (delivery depends on '
                      'server email configuration). Copy and share this link '
                      'as a backup.'
                  : 'No invitation email was sent. Copy and share this link '
                      'with the contractor.',
            ),
            const SizedBox(height: 12),
            SelectableText(inviteUrl),
            const SizedBox(height: 8),
            Text(
              'Expires ${expiresAt.toLocal()}.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteUrl));
              Get.back();
              Get.snackbar(
                'Copied',
                inviteUrl,
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(16),
              );
            },
            child: const Text('Copy link'),
          ),
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> runAction(String action, EngagementOut engagement) async {
    if (action == 'end' || action == 'withdraw') {
      final isWithdraw = action == 'withdraw' || engagement.isInvited;
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: Text(isWithdraw ? 'Withdraw invite?' : 'End engagement?'),
          content: Text(
            isWithdraw
                ? 'This will withdraw the invite for ${engagement.displayName}. '
                    'They will no longer be able to accept this invitation.'
                : 'This will end the engagement with ${engagement.displayName}. '
                    'This cannot be undone from here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(isWithdraw ? 'Withdraw invite' : 'End engagement'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    isSaving.value = true;
    clearError();
    try {
      final updated = await switch (action) {
        'approve' => _repository.approve(engagement.id),
        'activate' => _repository.activate(engagement.id),
        'approve_and_activate' => _repository.approveAndActivate(engagement.id),
        'suspend' => _repository.suspend(engagement.id),
        'resume' => _repository.resume(engagement.id),
        'end' || 'withdraw' => _repository.end(engagement.id),
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
      _setError(e.message);
      if (e.isEligibilityIncomplete) {
        eligibilityReasons.assignAll(e.eligibilityReasons);
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _ensureListPhotosLoaded() async {
    if (!canRead) return;
    final contractorIds =
        items.map((e) => e.contractorId).where((id) => id.isNotEmpty).toSet();
    final pending =
        contractorIds.where((id) => !photosByContractor.containsKey(id)).toList();
    if (pending.isEmpty) return;

    final results = await Future.wait(
      pending.map((id) async {
        try {
          return MapEntry(id, await _repository.getContractorProfilePhoto(id));
        } on AppFailure {
          return MapEntry(id, null);
        } catch (_) {
          return MapEntry(id, null);
        }
      }),
    );
    for (final entry in results) {
      final photo = entry.value;
      if (photo != null) {
        photosByContractor[entry.key] = photo;
      }
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
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
    } finally {
      isLoadingCredentials.value = false;
    }
  }

  void openCredentialReview(EngagementOut engagement) {
    if (engagement.isEnded) {
      _setError('This worker is no longer in your workforce.');
      return;
    }
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
