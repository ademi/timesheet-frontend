import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../contractor_onboarding/data/models/compliance_models.dart';
import '../../contractor_onboarding/data/repositories/compliance_repository.dart';
import '../data/models/engagement_models.dart';
import '../data/repositories/engagements_repository.dart';

/// Contractor engagements + accept with sharing grant (design §5.5).
class ContractorEngagementsController extends GetxController {
  ContractorEngagementsController({
    required EngagementsRepository repository,
    required ComplianceRepository complianceRepository,
    required SessionService session,
  }) : _repository = repository,
       _compliance = complianceRepository,
       _session = session;

  final EngagementsRepository _repository;
  final ComplianceRepository _compliance;
  final SessionService _session;

  final items = <EngagementOut>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  /// Engagement being accepted (grant UI).
  final accepting = Rxn<EngagementOut>();
  final allowSourceEvidence = false.obs;
  final understoodWithdrawEffects = false.obs;
  final authorisationRecorded = false.obs;

  List<EngagementOut> get invited =>
      items.where((e) => e.isInvited).toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repository.listMyEngagements();
      items.assignAll(list);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void beginAccept(EngagementOut engagement) {
    accepting.value = engagement;
    allowSourceEvidence.value = false;
    understoodWithdrawEffects.value = false;
    authorisationRecorded.value = false;
    errorMessage.value = null;
  }

  void cancelAccept() {
    accepting.value = null;
  }

  /// Record engagement-scoped sharing authorisation legal event, then accept.
  Future<bool> confirmAccept() async {
    final eng = accepting.value;
    if (eng == null) return false;
    if (!understoodWithdrawEffects.value) {
      errorMessage.value =
          'Confirm you understand withdrawal / end-engagement effects.';
      return false;
    }

    isSaving.value = true;
    errorMessage.value = null;
    try {
      if (!authorisationRecorded.value) {
        await _compliance.createLegalEvent(
          LegalEventCreate(
            eventType: 'consented',
            engagementId: eng.id,
            dataClass: 'sharing_grant',
            presentationSource: 'engagement_accept',
          ),
        );
        authorisationRecorded.value = true;
      }

      final updated = await _repository.accept(
        engagementId: eng.id,
        body: EngagementAcceptRequest(
          allowSourceEvidence: allowSourceEvidence.value,
        ),
      );

      final idx = items.indexWhere((e) => e.id == updated.id);
      if (idx >= 0) {
        items[idx] = updated;
      } else {
        await load();
      }

      // Refresh session engagement statuses when possible.
      try {
        await _session.hydrateFromMeContext();
      } catch (_) {}

      accepting.value = null;
      Get.snackbar(
        'Engagement accepted',
        'Status is now ${updated.status}. Continue with required credentials.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = _acceptErrorMessage(e);
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  String _acceptErrorMessage(AppFailure failure) {
    if (failure.code.startsWith('sharing_authorisation') ||
        failure.code == 'legal_document_unavailable') {
      return 'Could not record sharing authorisation. Try again or contact support.';
    }
    return failure.message;
  }
}
