import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/utils/name_sort.dart';
import '../../contractor_onboarding/bindings/onboarding_binding.dart';
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
    void Function(String route)? onNavigateHome,
  }) : _repository = repository,
       _compliance = complianceRepository,
       _session = session,
       _onNavigateHome = onNavigateHome ?? _navigateHome;

  final EngagementsRepository _repository;
  final ComplianceRepository _compliance;
  final SessionService _session;
  final void Function(String route) _onNavigateHome;

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
      sortedByName(items.where((e) => e.isInvited), (e) => e.tenantName ?? e.tenantId);

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
        // The accept response is the authoritative updated entity. Retain it
        // instead of issuing another tenant-scoped engagements list request.
        items.add(updated);
      }

      await _session.switchTenant(updated.tenantId);

      accepting.value = null;
      _onNavigateHome(AppRoutes.contractorHome);
      OnboardingBinding.reset();
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

  static void _navigateHome(String route) => Get.offAllNamed(route);
}
