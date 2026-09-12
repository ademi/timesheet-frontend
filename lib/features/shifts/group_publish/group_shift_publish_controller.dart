import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../billing/data/models/billing_models.dart';
import '../../billing/data/repositories/ndis_catalogue_repository.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../data/models/shift_models.dart';
import '../data/repositories/shifts_repository.dart';
import '../utils/participant_display.dart';
import '../utils/publish_draft.dart';
import '../utils/publish_estimate_math.dart';
import 'group_shift_publish_args.dart';
import 'group_shift_publish_override_view.dart';

/// Full-screen Publish group shift wizard (Item · People · Stay · Review).
class GroupShiftPublishController extends GetxController {
  GroupShiftPublishController({
    required ShiftsRepository shiftsRepository,
    required JobsRepository jobsRepository,
    required NdisCatalogueRepository catalogueRepository,
    required this.args,
    void Function(dynamic result)? onPop,
    Future<PublishParticipantOverrideDraft?> Function(
      GroupShiftPublishOverrideArgs args,
    )?
    openOverrideEditor,
  }) : _shifts = shiftsRepository,
       _jobs = jobsRepository,
       _catalogue = catalogueRepository,
       _onPop = onPop,
       _openOverrideEditor = openOverrideEditor;

  final ShiftsRepository _shifts;
  final JobsRepository _jobs;
  final NdisCatalogueRepository _catalogue;
  final GroupShiftPublishArgs args;
  final void Function(dynamic result)? _onPop;
  final Future<PublishParticipantOverrideDraft?> Function(
    GroupShiftPublishOverrideArgs args,
  )?
  _openOverrideEditor;

  static const int itemStep = 0;
  static const int peopleStep = 1;
  static const int stayStep = 2;
  static const int reviewStep = 3;
  static const int maxStep = reviewStep;
  static const stepLabels = ['Item', 'People', 'Stay', 'Review'];

  final step = 0.obs;
  final draft = const PublishDraft().obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  /// support_item_number → national price limit (parsed).
  final catalogueNationalByCode = <String, double>{}.obs;
  final catalogueByCode = <String, NdisCatalogueItemOut>{}.obs;

  ShiftOut get shift => args.shift;

  List<ShiftParticipantOut> get active =>
      activeParticipants(shift.participants);

  List<ParticipantPublishEstimate> get estimates => estimatePublishClaims(
    activeParticipants: active,
    scheduledStart: shift.scheduledStart,
    scheduledEnd: shift.scheduledEnd,
    draft: draft.value,
    catalogueNationalByCode: Map<String, double>.from(
      catalogueNationalByCode,
    ),
  );

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await Future.wait([_prefillFromJob(), _loadCatalogue()]);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _prefillFromJob() async {
    try {
      final job = await _jobs.getJob(shift.jobId);
      final code = job.supportItemCode?.trim();
      if (code == null || code.isEmpty) return;
      if ((draft.value.supportItemCode ?? '').trim().isNotEmpty) return;
      draft.value = draft.value.copyWith(
        supportItemCode: code,
        supportItemName: job.supportItemName,
      );
    } on AppFailure {
      // Prefill is best-effort; staff can still pick an item.
    }
  }

  Future<void> _loadCatalogue() async {
    final items = await _catalogue.fetchAllActiveItems();
    final byCode = <String, NdisCatalogueItemOut>{};
    final prices = <String, double>{};
    for (final item in items) {
      byCode[item.supportItemNumber] = item;
      final raw = item.priceLimitNational?.trim();
      if (raw == null || raw.isEmpty) continue;
      final parsed = double.tryParse(raw);
      if (parsed != null) prices[item.supportItemNumber] = parsed;
    }
    catalogueByCode.assignAll(byCode);
    catalogueNationalByCode.assignAll(prices);
  }

  void setDefaultItem({
    required String? supportItemCode,
    required String? supportItemName,
  }) {
    draft.value = draft.value.copyWith(
      supportItemCode: supportItemCode,
      supportItemName: supportItemName,
      clearSupportItem: supportItemCode == null || supportItemCode.isEmpty,
    );
    errorMessage.value = null;
  }

  void setAccommodationEnabled(bool enabled) {
    if (!enabled) {
      draft.value = draft.value.copyWith(
        accommodationEnabled: false,
        clearAccommodationItem: true,
        clearAccommodationQuantity: true,
      );
    } else {
      final qty = draft.value.accommodationQuantity;
      draft.value = draft.value.copyWith(
        accommodationEnabled: true,
        accommodationQuantity:
            (qty == null || qty.trim().isEmpty) ? '1' : qty,
      );
    }
    errorMessage.value = null;
  }

  void setAccommodationItem({
    required String? supportItemCode,
    required String? supportItemName,
  }) {
    draft.value = draft.value.copyWith(
      accommodationSupportItemCode: supportItemCode,
      accommodationSupportItemName: supportItemName,
      clearAccommodationItem:
          supportItemCode == null || supportItemCode.isEmpty,
    );
    errorMessage.value = null;
  }

  void setAccommodationQuantity(String? qty) {
    draft.value = draft.value.copyWith(
      accommodationQuantity: qty,
      clearAccommodationQuantity: qty == null || qty.trim().isEmpty,
    );
    errorMessage.value = null;
  }

  void clearOverride(String participantId) {
    final next = Map<String, PublishParticipantOverrideDraft>.from(
      draft.value.overrides,
    )..remove(participantId);
    draft.value = draft.value.copyWith(overrides: next);
    errorMessage.value = null;
  }

  void upsertOverride(PublishParticipantOverrideDraft override) {
    final next = Map<String, PublishParticipantOverrideDraft>.from(
      draft.value.overrides,
    );
    if (override.isEmpty) {
      next.remove(override.participantId);
    } else {
      next[override.participantId] = override;
    }
    draft.value = draft.value.copyWith(overrides: next);
    errorMessage.value = null;
  }

  Future<void> openCustomOverride(ShiftParticipantOut participant) async {
    final existing = draft.value.overrideFor(participant.participantId);
    final editorArgs = GroupShiftPublishOverrideArgs(
      participant: participant,
      defaultItemCode: draft.value.supportItemCode,
      defaultItemName: draft.value.supportItemName,
      initial: existing,
    );
    final opener = _openOverrideEditor;
    final result =
        opener != null
            ? await opener(editorArgs)
            : await Get.to<PublishParticipantOverrideDraft?>(
              () => GroupShiftPublishOverrideView(args: editorArgs),
            );
    if (result == null) return;
    if (result.isEmpty) {
      clearOverride(participant.participantId);
    } else {
      upsertOverride(result);
    }
  }

  void previousStep() {
    if (step.value <= 0 || isSaving.value) return;
    step.value -= 1;
    errorMessage.value = null;
  }

  void nextStep() {
    if (isSaving.value) return;
    final err = switch (step.value) {
      itemStep => draft.value.validateDefaultItem(),
      peopleStep => draft.value.validateOverrides(),
      stayStep => draft.value.validateAccommodation(),
      _ => null,
    };
    if (err != null) {
      errorMessage.value = err;
      return;
    }
    if (step.value >= maxStep) return;
    step.value += 1;
    errorMessage.value = null;
  }

  Future<void> publish() async {
    if (isSaving.value) return;
    final err = draft.value.validateAll();
    if (err != null) {
      errorMessage.value = err;
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final published = await _shifts.publishShift(
        shift.id,
        body: draft.value.toRequest(),
      );
      if (!Get.testMode) {
        AppToast.success('Published', published.jobTitle);
      }
      final pop = _onPop;
      if (pop != null) {
        pop(published);
      } else {
        Get.back(result: published);
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) {
        AppToast.error('Could not publish', e.message);
      }
      // Stay on Review (D6).
    } finally {
      isSaving.value = false;
    }
  }

  void cancel() {
    final pop = _onPop;
    if (pop != null) {
      pop(null);
    } else {
      Get.back();
    }
  }

  String participantEstimateLabel(String participantId) {
    final est = estimates.where((e) => e.participantId == participantId);
    if (est.isEmpty) return 'est. —';
    return formatEstimateMoney(est.first.total);
  }

  String customCaption(String participantId) {
    final o = draft.value.overrideFor(participantId);
    if (o == null) return 'default';
    if (o.supportItemCode != null && o.supportItemCode!.isNotEmpty) {
      return 'custom item';
    }
    if (o.hasAnyRate) return 'custom rate';
    return 'custom';
  }
}
