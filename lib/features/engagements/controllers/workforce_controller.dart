import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../../app/utils/email_utils.dart';
import '../../../shared/utils/name_sort.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../credentials/data/models/credential_models.dart';
import '../../credentials/data/repositories/credentials_repository.dart';
import '../../credentials/utils/credential_expiry.dart';
import '../../credentials/utils/support_worker_pack.dart';
import '../../visits/data/models/roster_overlay_models.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../../visits/utils/visit_windows.dart';
import '../data/models/engagement_models.dart';
import '../data/models/staff_contractor_models.dart';
import '../data/repositories/engagements_repository.dart';
import '../utils/missing_categories.dart';
import '../widgets/invite_sent_dialog.dart';
import '../widgets/pending_invite_contact_dialog.dart';

class WorkforceController extends GetxController {
  WorkforceController({
    required EngagementsRepository repository,
    required CredentialsRepository credentialsRepository,
    required SessionService session,
    VisitsRepository? visits,
  }) : _repository = repository,
       _credentialsRepository = credentialsRepository,
       _session = session,
       _visits = visits;

  final EngagementsRepository _repository;
  final CredentialsRepository _credentialsRepository;
  final SessionService _session;
  final VisitsRepository? _visits;

  final items = <EngagementOut>[].obs;
  final pendingInvites = <ContractorRegistrationInviteOut>[].obs;

  /// Exclusive list chip: `null` = All; engagement status; [filterMissingDocs];
  /// [filterExpiring]. Selecting one mode always clears the others.
  final listFilter = RxnString();
  static const filterMissingDocs = 'missing_docs';
  static const filterExpiring = 'expiring';

  /// Hard screening types counted by the Home expiry digest.
  static const _digestHardTypes = {
    'ndis_worker_screening',
    'police_check',
    'wwcc',
  };
  static const _expiringWithinDays = 30;

  final credentialsByContractor = <String, List<CredentialOut>>{}.obs;
  final isLoadingCredentials = false.obs;
  final photosByContractor = <String, ProfilePhotoOut>{}.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final resendingInviteId = RxnString();
  final updatingInviteId = RxnString();
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
  final upcomingVisits = <VisitOut>[].obs;
  final pastVisits = <VisitOut>[].obs;
  final isLoadingVisits = false.obs;
  final visitsError = RxnString();
  final visitsTruncated = false.obs;
  final detailAvailability = <AvailabilityRuleOut>[].obs;
  final isLoadingAvailability = false.obs;
  final scheduleError = RxnString();

  EngagementOut? get selected => selectedRx.value;
  set selected(EngagementOut? value) => selectedRx.value = value;
  final selectedRx = Rxn<EngagementOut>();

  bool _detailExtrasLoaded = false;

  static const tabOverview = 0;
  static const tabProfile = 1;
  static const tabCredentials = 2;
  static const tabVisits = 3;
  static const tabSchedule = 4;

  final staffProfile = Rxn<StaffContractorOut>();
  final isLoadingProfile = false.obs;

  /// Invite multi-select options (catalog when loaded, else allowlist fallback).
  List<CredentialCategory> get inviteCategoryChoices {
    final choices =
        catalogCategories.isNotEmpty
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
  bool get canViewVisits =>
      _session.hasPermission(AppPermissions.visitsRead) ||
      _session.hasPermission(AppPermissions.visitsManage) ||
      _session.hasPermission(AppPermissions.jobsManage);

  bool get isAllFilter => listFilter.value == null;
  bool get isMissingDocsFilter => listFilter.value == filterMissingDocs;
  bool get isExpiringFilter => listFilter.value == filterExpiring;
  bool get isStatusFilter {
    final f = listFilter.value;
    return f != null && f != filterMissingDocs && f != filterExpiring;
  }

  bool isStatusSelected(String status) => listFilter.value == status;

  List<EngagementOut> get filtered {
    var list = items.toList();
    final f = listFilter.value;
    if (f == null) {
      // All
    } else if (f == filterMissingDocs) {
      list = list.where(hasMissingRequiredDocs).toList();
    } else if (f == filterExpiring) {
      // Align with Home digest (active engagements + hard screening types).
      list =
          list
              .where(
                (e) =>
                    e.status == 'active' && hasDigestExpiringCredentials(e),
              )
              .toList();
    } else {
      list = list.where((e) => e.status == f).toList();
    }
    list.sort((a, b) => compareNames(a.displayName, b.displayName));
    return list;
  }

  /// Pending registration invites shown when filter is All or Invited.
  List<ContractorRegistrationInviteOut> get filteredPendingInvites {
    final f = listFilter.value;
    if (f == filterMissingDocs || f == filterExpiring) return const [];
    if (f != null && f != 'invited') return const [];
    final list =
        pendingInvites.toList()..sort(
          (a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        );
    return list;
  }

  bool hasMissingRequiredDocs(EngagementOut engagement) =>
      missingCategories(
        engagement,
        credentialsByContractor[engagement.contractorId] ?? const [],
      ).isNotEmpty;

  /// Matches Home digest: active hard-category creds expiring within 30 days.
  bool hasDigestExpiringCredentials(EngagementOut engagement) {
    final creds =
        credentialsByContractor[engagement.contractorId] ?? const [];
    for (final c in creds) {
      if (!_isDigestExpiringCredential(c)) continue;
      return true;
    }
    return false;
  }

  bool _isDigestExpiringCredential(CredentialOut c) {
    if (c.status != 'active') return false;
    if (!_digestHardTypes.contains(c.credentialType)) return false;
    final days = daysUntilExpiry(c.expiresOn);
    if (days == null) return false;
    // Digest bands use expires_on >= today and <= horizon (not already expired).
    return days >= 0 && days <= _expiringWithinDays;
  }

  String? expiringCredentialsSubtitle(EngagementOut engagement) {
    final creds =
        credentialsByContractor[engagement.contractorId] ?? const [];
    String? best;
    var bestDays = 1 << 30;
    for (final c in creds) {
      if (!_isDigestExpiringCredential(c)) continue;
      final days = daysUntilExpiry(c.expiresOn)!;
      if (days < bestDays) {
        bestDays = days;
        best =
            '${c.displayLabel} · ${credentialExpiryLabel(c.expiresOn) ?? 'Expiring'}';
      }
    }
    return best;
  }

  /// One chip at a time: All / status / Missing docs / Expiring.
  Future<void> selectListFilter(String? mode) async {
    listFilter.value = mode;
    if (mode == filterMissingDocs || mode == filterExpiring) {
      await _ensureCredentialsLoaded();
    }
  }

  Future<void> applyRouteFilterFromQuery() async {
    final raw =
        Get.parameters['filter'] ??
        Uri.tryParse(AppNavigator.currentLocation)?.queryParameters['filter'];
    if (raw == filterExpiring || raw == 'expiring') {
      await selectListFilter(filterExpiring);
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever(tabIndex, _onTabChanged);
    if (_routeImpliesDetail()) {
      isLoading.value = true;
    }
    Future.microtask(() async {
      await load();
      await applyRouteFilterFromQuery();
      await ensureDetailHydratedFromRoute();
    });
  }

  /// Tier-2 shell re-enter: soft list refresh; re-apply deep-link filter if any.
  void onScreenReenter() {
    final path =
        Uri.tryParse(AppNavigator.currentLocation)?.path ??
        AppNavigator.currentLocation;
    // Same false-reenter path as clients: GoRouter rebuilds under a push.
    if (!_isWorkforceSurface(path)) return;

    clearError();
    // ignore: discarded_futures
    load().then((_) => applyRouteFilterFromQuery());
    // ignore: discarded_futures
    ensureDetailHydratedFromRoute();
  }

  static bool _isWorkforceSurface(String path) =>
      path == AppRoutes.staffWorkforce ||
      path.startsWith('${AppRoutes.staffWorkforce}/');

  bool _routeImpliesDetail() {
    if (selected != null) return false;
    if (Get.arguments is EngagementOut) return true;
    final id = Get.parameters['id'];
    return id != null && id.isNotEmpty;
  }

  /// Call from detail so a fresh controller still loads after web refresh.
  Future<void> ensureDetailHydratedFromRoute() async {
    if (selected != null) return;

    EngagementOut? found;
    final fromArgs = Get.arguments;
    if (fromArgs is EngagementOut) {
      found = fromArgs;
    } else {
      final id = Get.parameters['id'];
      if (id != null && id.isNotEmpty) {
        if (items.isEmpty) await load();
        for (final e in items) {
          if (e.id == id) {
            found = e;
            break;
          }
        }
      }
    }
    if (found == null) return;
    await _bindDetail(found);
  }

  void _onTabChanged(int tab) {
    if (tab == tabVisits || tab == tabSchedule) {
      unawaited(_ensureDetailExtrasLoaded());
    }
  }

  Future<void> _ensureDetailExtrasLoaded() async {
    if (_detailExtrasLoaded || selected == null) return;
    _detailExtrasLoaded = true;
    await Future.wait([loadDetailVisits(), loadDetailAvailability()]);
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
      final results = await Future.wait([
        _repository.listTenantEngagements(),
        _repository.listPendingContractorInvites(),
      ]);
      items.assignAll(results[0] as List<EngagementOut>);
      pendingInvites.assignAll(
        results[1] as List<ContractorRegistrationInviteOut>,
      );
      photosByContractor.clear();
      // Load avatars in the background so the list can render immediately.
      _ensureListPhotosLoaded();
      if (isMissingDocsFilter || isExpiringFilter) {
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
    AppNavigator.push(
      AppNavigator.location(
        AppRoutes.staffWorkforceDetail,
        query: {'id': e.id},
      ),
      extra: e,
    );
    unawaited(_bindDetail(e));
  }

  Future<void> _bindDetail(EngagementOut e) async {
    selected = e;
    tabIndex.value = tabOverview;
    _detailExtrasLoaded = false;
    upcomingVisits.clear();
    pastVisits.clear();
    visitsError.value = null;
    visitsTruncated.value = false;
    detailAvailability.clear();
    scheduleError.value = null;
    staffProfile.value = null;
    clearError();
    detailPhoto.value = photosByContractor[e.contractorId];
    detailSelectedCategories
      ..clear()
      ..addAll(e.requiredDocCategories.map((c) => c.category));
    if (canManage && !e.isEnded) {
      await loadCredentialCategories();
    }
    await Future.wait([
      loadDetailProfilePhoto(e.contractorId),
      loadStaffProfile(e.contractorId),
    ]);
  }

  Future<void> loadStaffProfile(String contractorId) async {
    isLoadingProfile.value = true;
    try {
      staffProfile.value = await _repository.getStaffContractor(contractorId);
    } on AppFailure catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
    } finally {
      isLoadingProfile.value = false;
    }
  }

  Future<void> loadDetailVisits() async {
    final engagement = selected;
    final visitsRepo = _visits;
    upcomingVisits.clear();
    pastVisits.clear();
    if (engagement == null || visitsRepo == null) {
      visitsTruncated.value = false;
      return;
    }
    if (!canViewVisits) {
      upcomingVisits.clear();
      pastVisits.clear();
      visitsError.value = null;
      visitsTruncated.value = false;
      return;
    }
    isLoadingVisits.value = true;
    visitsError.value = null;
    try {
      final now = DateTime.now().toUtc();
      final list = await visitsRepo.listVisits(
        contractorId: engagement.contractorId,
        from: now.subtract(clientVisitLookback),
        to: now.add(clientVisitLookahead),
        limit: clientVisitFetchLimit,
      );
      visitsTruncated.value = list.length >= clientVisitFetchLimit;
      final parts = partitionClientVisits(list, now: now);
      upcomingVisits.assignAll(parts.upcoming);
      pastVisits.assignAll(parts.past);
    } on AppFailure catch (e) {
      visitsError.value = e.message;
      upcomingVisits.clear();
      pastVisits.clear();
    } finally {
      isLoadingVisits.value = false;
    }
  }

  Future<void> loadDetailAvailability() async {
    final engagement = selected;
    detailAvailability.clear();
    scheduleError.value = null;
    if (engagement == null) return;
    isLoadingAvailability.value = true;
    try {
      final rules = await _repository.listAvailability(engagement.id);
      detailAvailability.assignAll(rules);
    } on AppFailure catch (e) {
      scheduleError.value = e.message;
      detailAvailability.clear();
    } finally {
      isLoadingAvailability.value = false;
    }
  }

  void openVisitDetail(VisitOut visit) {
    // Query id only — GoRouter drops complex `extra` maps without a codec.
    AppNavigator.push(
      AppNavigator.location(
        AppRoutes.staffVisitDetail,
        query: {'id': visit.id},
      ),
    );
  }

  Future<void> loadDetailProfilePhoto(String contractorId) async {
    if (contractorId.isEmpty || !canRead) return;
    isDetailPhotoLoading.value = true;
    try {
      detailPhoto.value = await _repository.getContractorProfilePhoto(
        contractorId,
      );
    } on AppFailure {
      detailPhoto.value = null;
    } catch (_) {
      detailPhoto.value = null;
    } finally {
      isDetailPhotoLoading.value = false;
    }
  }

  /// Support Worker pack always-required codes (locked on invite UI).
  Set<String> get invitePackDefaultCategories =>
      Set<String>.from(SupportWorkerPack.alwaysRequired);

  /// Seed invite multi-select with the global Support Worker always-required set.
  void seedInvitePackDefaults() {
    selectedCategories
      ..clear()
      ..addAll(SupportWorkerPack.alwaysRequired);
  }

  void toggleCategory(String category) {
    // Pack defaults stay selected; staff may only add extras.
    if (SupportWorkerPack.alwaysRequired.contains(category)) {
      if (!selectedCategories.contains(category)) {
        selectedCategories.add(category);
      }
      return;
    }
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
      _setError('This support worker is no longer in your directory.');
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
    final email = emailCtrl.text.trim().toLowerCase();
    final phone = phoneCtrl.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      _setError('Provide an email and/or phone.');
      return;
    }
    if (email.isNotEmpty && !EmailUtils.isValid(email)) {
      _setError(EmailUtils.formatHint);
      return;
    }
    // Always union pack defaults ∪ staff extras (never drop pack always).
    final categories =
        {...SupportWorkerPack.alwaysRequired, ...selectedCategories}.toList()
          ..sort();
    if (categories.isEmpty) {
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

      final result = await _repository.invite(
        EngagementInviteRequest(
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
          requiredCategories: categories,
          sendEmail: true,
        ),
      );
      emailCtrl.clear();
      phoneCtrl.clear();
      seedInvitePackDefaults();
      // Prefer AppNavigator: Get.back() needs Get.key attached to a Navigator,
      // which GetMaterialApp.router does not set unless GoRouter uses Get.key.
      AppNavigator.pop();
      final invite = result.registrationInvite;
      if (result.isRegistrationInvite && invite != null) {
        await _showInviteSentConfirmation(expiresAt: invite.expiresAt);
      } else {
        AppToast.success(
          result.isRegistrationInvite ? 'Invite sent' : 'Engagement created',
          result.isRegistrationInvite
              ? 'Invitation email sent. You can re-email from the support workers list.'
              : 'Invitation email sent to this support worker.',
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

  Future<void> resendPendingInvite(
    ContractorRegistrationInviteOut invite,
  ) async {
    if (!canInvite) {
      _setError('Missing contractors.invite permission.');
      return;
    }
    resendingInviteId.value = invite.id;
    clearError();
    try {
      final updated = await _repository.resendContractorInvite(invite.id);
      final idx = pendingInvites.indexWhere((e) => e.id == invite.id);
      if (idx >= 0) {
        pendingInvites.removeAt(idx);
      }
      pendingInvites.insert(0, updated);
      AppToast.success(
        'Invite re-sent',
        'Invitation email sent to ${updated.email}.',
      );
      await _showInviteSentConfirmation(expiresAt: updated.expiresAt);
    } on AppFailure catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
    } finally {
      resendingInviteId.value = null;
    }
  }

  Future<void> updatePendingInviteContact(
    ContractorRegistrationInviteOut invite,
  ) async {
    if (!canInvite) {
      _setError('Missing contractors.invite permission.');
      return;
    }
    final result = await Get.dialog<Map<String, String?>>(
      PendingInviteContactDialog(invite: invite),
    );
    if (result == null) return;

    final newEmail = EmailUtils.normalize(result['email'] ?? '');
    final phoneRaw = result['phone'] ?? '';
    final emailChanged = newEmail != EmailUtils.normalize(invite.email);
    final phoneChanged = phoneRaw != (invite.phone ?? '');
    if (!emailChanged && !phoneChanged) return;

    updatingInviteId.value = invite.id;
    clearError();
    try {
      final updated = await _repository.updateContractorInvite(
        invite.id,
        email: newEmail,
        phone: phoneRaw,
      );
      final idx = pendingInvites.indexWhere((e) => e.id == invite.id);
      if (idx >= 0) {
        pendingInvites.removeAt(idx);
      }
      pendingInvites.insert(0, updated);
      if (emailChanged) {
        AppToast.success(
          'Invite updated',
          'A new invitation was sent to ${updated.email}.',
        );
        await _showInviteSentConfirmation(expiresAt: updated.expiresAt);
      } else {
        AppToast.success(
          'Contact updated',
          'Phone number saved for this invite.',
        );
      }
    } on AppFailure catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
    } finally {
      updatingInviteId.value = null;
    }
  }

  Future<void> resendEngagementInviteEmail(EngagementOut engagement) async {
    if (!canInvite) {
      _setError('Missing contractors.invite permission.');
      return;
    }
    if (!engagement.isInvited) return;
    resendingInviteId.value = engagement.id;
    clearError();
    try {
      await _repository.resendEngagementInvite(engagement.id);
      AppToast.success(
        'Invite re-sent',
        'Invitation email sent to ${engagement.contractorEmail ?? engagement.displayName}.',
      );
    } on AppFailure catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(e.toString());
    } finally {
      resendingInviteId.value = null;
    }
  }

  Future<void> _showInviteSentConfirmation({
    required DateTime expiresAt,
  }) async {
    await Get.dialog<void>(InviteSentDialog(expiresAt: expiresAt));
  }

  Future<void> runAction(String action, EngagementOut engagement) async {
    final needsApprove =
        action == 'approve' || action == 'approve_and_activate';
    final needsManage = action == 'activate' ||
        action == 'suspend' ||
        action == 'resume' ||
        action == 'end' ||
        action == 'withdraw';
    if (needsApprove && !canApprove) {
      _setError('You don’t have access to approve support workers.');
      return;
    }
    if (needsManage && !canManage) {
      _setError('You don’t have access to manage this engagement.');
      return;
    }

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
      AppToast.success(
        'Updated',
        'Engagement is now ${engagementStatusLabel(updated.status)}.',
      );
    } on AppFailure catch (e) {
      _setError(
        e.isAccessDenied
            ? 'You don’t have access to this action.'
            : e.message,
      );
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
        contractorIds
            .where((id) => !photosByContractor.containsKey(id))
            .toList();
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
    final contractorIds = <String>{};
    for (final engagement in items) {
      contractorIds.add(engagement.contractorId);
    }
    final pending =
        contractorIds
            .where((id) => !credentialsByContractor.containsKey(id))
            .toList();
    if (pending.isEmpty) return;

    isLoadingCredentials.value = true;
    try {
      // No engagement_id: metadata without sharing grant (matches digest).
      final results = await Future.wait(
        pending.map(
          (contractorId) =>
              _credentialsRepository.listForTenantContractor(contractorId),
        ),
      );
      for (var i = 0; i < pending.length; i++) {
        credentialsByContractor[pending[i]] = results[i];
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
      _setError('This support worker is no longer in your directory.');
      return;
    }
    AppNavigator.push(
      AppNavigator.location(
        AppRoutes.staffCredentialReview,
        query: {
          'contractorId': engagement.contractorId,
          'engagementId': engagement.id,
        },
      ),
      extra: {
        'contractorId': engagement.contractorId,
        'engagementId': engagement.id,
        'requiredCategories':
            engagement.requiredDocCategories.map((c) => c.category).toList(),
        'canEditRequiredDocs': canManage && !engagement.isEnded,
        'isEnded': engagement.isEnded,
      },
    );
  }
}
