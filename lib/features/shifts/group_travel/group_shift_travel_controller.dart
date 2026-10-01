import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../features/billing/bindings/billing_binding.dart';
import '../../../features/billing/data/models/billing_models.dart';
import '../../../features/billing/data/repositories/ndis_catalogue_repository.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/shift_models.dart';
import '../data/models/shift_travel_models.dart';
import '../data/repositories/shifts_repository.dart';
import '../utils/participant_display.dart';
import '../utils/travel_apportionment.dart';
import '../utils/travel_draft.dart';
import '../utils/travel_item_rules.dart';
import 'group_shift_travel_args.dart';

/// Anchor support-item codes for option 4 (registration-group narrowing).
List<String> travelAnchorCodes({
  required TravelApportionmentMode mode,
  required String? nominatedParticipantId,
  required List<ShiftParticipantOut> active,
}) {
  if (mode == TravelApportionmentMode.nominated) {
    final nominee = active.where((p) => p.id == nominatedParticipantId);
    final code =
        nominee.isEmpty
            ? null
            : nominee.first.rateSnapshot?.supportItemCode?.trim();
    return (code == null || code.isEmpty) ? const [] : [code];
  }
  return [
    for (final p in active)
      if ((p.rateSnapshot?.supportItemCode ?? '').trim().isNotEmpty)
        p.rateSnapshot!.supportItemCode!.trim(),
  ];
}

bool travelEqualHasMixedRegistrationGroups(List<String> anchors) =>
    uniqueRegistrationGroups(anchors).length > 1;

class GroupShiftTravelController extends GetxController {
  GroupShiftTravelController({
    required ShiftsRepository shiftsRepository,
    required this.args,
    void Function(dynamic result)? onPop,
    NdisCatalogueRepository? catalogueRepository,
  }) : _shifts = shiftsRepository,
       _onPop = onPop,
       _catalogueOverride = catalogueRepository {
    final existing = args.existing;
    draft =
        TravelDraft(
          supportItemCode: existing?.supportItemCode,
          // Name is hydrated from the catalogue in [onReady] (API has code only).
          supportItemName: null,
          quantity: existing == null ? null : _formatQty(existing.quantity),
          notes: existing?.notes,
          apportionmentMode:
              existing?.apportionmentMode ?? TravelApportionmentMode.equal,
          nominatedParticipantId: existing?.nominatedParticipantId,
        ).obs;
  }

  final ShiftsRepository _shifts;
  final GroupShiftTravelArgs args;
  final void Function(dynamic result)? _onPop;
  final NdisCatalogueRepository? _catalogueOverride;

  static const itemStep = 0;
  static const splitStep = 1;
  static const reviewStep = 2;
  static const maxStep = reviewStep;
  static const stepLabels = ['Item', 'Split', 'Review'];

  static const itemClearedHelperMessage =
      'Pick a travel item that matches this participant.';
  static const noAnchorsHelperMessage =
      'Showing all provider travel / activity transport items. Publish the shift to narrow by participant support item.';
  static const mixedEqualErrorMessage =
      'These participants have different NDIS support types, so one shared travel item can’t be split equally. Switch to Nominated, or add a separate travel claim per support type.';

  final step = itemStep.obs;
  late final Rx<TravelDraft> draft;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  /// Muted helper after mode/nominee change cleared an invalid support item (D3).
  final itemClearedHelper = RxnString();

  @override
  void onReady() {
    super.onReady();
    hydrateSupportItemName();
  }

  NdisCatalogueRepository get _catalogue {
    final override = _catalogueOverride;
    if (override != null) return override;
    BillingBinding.ensureShared();
    return Get.find<NdisCatalogueRepository>();
  }

  /// Resolve catalogue display name for an existing travel code (edit flow).
  Future<void> hydrateSupportItemName() async {
    final code = draft.value.supportItemCode?.trim();
    if (code == null || code.isEmpty) return;
    final currentName = draft.value.supportItemName?.trim();
    if (currentName != null &&
        currentName.isNotEmpty &&
        currentName != code) {
      return;
    }
    try {
      final items = await _catalogue.fetchAllActiveItems();
      for (final item in items) {
        if (item.supportItemNumber == code) {
          draft.value = draft.value.copyWith(
            supportItemCode: code,
            supportItemName: item.supportItemName,
          );
          return;
        }
      }
    } catch (_) {
      // Soft: leave name empty; picker still works once catalogue loads.
    }
  }

  ShiftOut get shift => args.shift;
  bool get isEditing => args.isEditing;
  List<ShiftParticipantOut> get active =>
      activeParticipants(shift.participants);
  List<String> get activeParticipantIds =>
      active.map((participant) => participant.id).toList(growable: false);

  List<String> get currentTravelAnchors => travelAnchorCodes(
    mode: draft.value.apportionmentMode,
    nominatedParticipantId: draft.value.nominatedParticipantId,
    active: active,
  );

  bool get hasMixedEqualRegistrationGroups =>
      draft.value.apportionmentMode == TravelApportionmentMode.equal &&
      travelEqualHasMixedRegistrationGroups(currentTravelAnchors);

  bool get hasTravelAnchors => currentTravelAnchors.isNotEmpty;

  /// Stable key so the picker remounts when anchors / split mode change.
  String get travelPickerKey =>
      '${draft.value.apportionmentMode.name}|'
      '${draft.value.nominatedParticipantId ?? ''}|'
      '${currentTravelAnchors.join(',')}';

  Map<String, double> get apportionedQuantities {
    final quantity = double.tryParse(draft.value.quantity?.trim() ?? '');
    if (quantity == null || quantity <= 0 || activeParticipantIds.isEmpty) {
      return const {};
    }
    return apportionTravelQuantity(
      mode: draft.value.apportionmentMode,
      totalQty: quantity,
      participantIds: activeParticipantIds,
      nominatedParticipantId: draft.value.nominatedParticipantId,
    );
  }

  bool travelCataloguePredicate(NdisCatalogueItemOut item) {
    if (item.unit != 'E') return false;
    if (!isTravelClaimableItemNumber(item.supportItemNumber)) return false;
    final anchors = currentTravelAnchors;
    if (draft.value.apportionmentMode == TravelApportionmentMode.equal &&
        travelEqualHasMixedRegistrationGroups(anchors)) {
      return false;
    }
    return travelCodeMatchesAnchors(
      travelCode: item.supportItemNumber,
      anchorCodes: anchors,
    );
  }

  bool _itemMatchesCurrentPredicate(String? code) {
    final trimmed = code?.trim() ?? '';
    if (trimmed.isEmpty) return true;
    return travelCataloguePredicate(
      NdisCatalogueItemOut(
        supportItemNumber: trimmed,
        supportItemName: draft.value.supportItemName ?? trimmed,
        unit: 'E',
      ),
    );
  }

  void _clearItemIfInvalidForCurrentAnchors() {
    final code = draft.value.supportItemCode;
    if (!_itemMatchesCurrentPredicate(code)) {
      draft.value = draft.value.copyWith(clearSupportItem: true);
      itemClearedHelper.value = itemClearedHelperMessage;
    }
  }

  void setItem({
    required String? supportItemCode,
    required String? supportItemName,
  }) {
    draft.value = draft.value.copyWith(
      supportItemCode: supportItemCode,
      supportItemName: supportItemName,
      clearSupportItem: supportItemCode == null || supportItemCode.isEmpty,
    );
    errorMessage.value = null;
    if (supportItemCode != null && supportItemCode.isNotEmpty) {
      itemClearedHelper.value = null;
    }
  }

  void setQuantity(String value) {
    draft.value = draft.value.copyWith(
      quantity: value,
      clearQuantity: value.trim().isEmpty,
    );
    errorMessage.value = null;
  }

  void setNotes(String value) {
    draft.value = draft.value.copyWith(notes: value, clearNotes: value.isEmpty);
    errorMessage.value = null;
  }

  void setMode(TravelApportionmentMode mode) {
    draft.value = draft.value.copyWith(
      apportionmentMode: mode,
      clearNominee: mode == TravelApportionmentMode.equal,
    );
    errorMessage.value = null;
    _clearItemIfInvalidForCurrentAnchors();
  }

  void setNominee(String? participantId) {
    draft.value = draft.value.copyWith(
      nominatedParticipantId: participantId,
      clearNominee: participantId == null,
    );
    errorMessage.value = null;
    _clearItemIfInvalidForCurrentAnchors();
  }

  void previousStep() {
    if (step.value <= itemStep || isSaving.value) return;
    step.value -= 1;
    errorMessage.value = null;
  }

  void nextStep() {
    if (isSaving.value) return;
    // Mixed equal: allow Item → Split so staff can switch to Nominated.
    // Block leaving Split (and save) until the split is fixed.
    if (hasMixedEqualRegistrationGroups && step.value >= splitStep) {
      errorMessage.value = mixedEqualErrorMessage;
      return;
    }
    final error = switch (step.value) {
      itemStep =>
        hasMixedEqualRegistrationGroups ? null : draft.value.validateItem(),
      splitStep =>
        draft.value.validateSplit() ??
            draft.value.validateReview(activeParticipantIds),
      _ => null,
    };
    if (error != null) {
      errorMessage.value = error;
      return;
    }
    if (step.value < maxStep) step.value += 1;
    errorMessage.value = null;
  }

  /// Jump to Split in Nominated mode when Equal cannot work (mixed reg groups).
  void switchToNominatedSplit() {
    setMode(TravelApportionmentMode.nominated);
    step.value = splitStep;
    errorMessage.value = null;
  }

  Future<void> save() async {
    if (isSaving.value) return;
    if (hasMixedEqualRegistrationGroups) {
      errorMessage.value = mixedEqualErrorMessage;
      return;
    }
    final error = draft.value.validateAll(activeParticipantIds);
    if (error != null) {
      errorMessage.value = error;
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final existing = args.existing;
      final saved =
          existing == null
              ? await _shifts.createTravel(shift.id, draft.value.toWrite())
              : await _shifts.updateTravel(
                shift.id,
                existing.id,
                draft.value.toWrite(),
              );
      if (!Get.testMode) {
        AppToast.success(
          isEditing ? 'Travel updated' : 'Travel added',
          saved.supportItemCode,
        );
      }
      _closeWizard(saved);
    } on AppFailure catch (failure) {
      step.value = reviewStep;
      errorMessage.value = _messageForFailure(failure);
      if (!Get.testMode) {
        AppToast.error('Could not save travel', errorMessage.value!);
      }
    } finally {
      isSaving.value = false;
    }
  }

  void cancel() => _closeWizard(null);

  /// Always return to the shift page: pop the wizard when possible, otherwise
  /// replace the stack with shift detail (deep-link / empty stack).
  void _closeWizard(dynamic result) {
    final pop = _onPop;
    if (pop != null) {
      pop(result);
      return;
    }
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) {
      Get.back(result: result);
      return;
    }
    Get.offNamed(AppRoutes.staffShiftDetail, arguments: shift);
  }

  String participantName(String shiftParticipantId) {
    for (final participant in active) {
      if (participant.id == shiftParticipantId) {
        return participant.participantName ?? participant.participantId;
      }
    }
    return shiftParticipantId;
  }

  static String formatShare(double quantity) => _formatQty(quantity);

  String _messageForFailure(AppFailure failure) {
    return switch (failure.code) {
      'travel_already_claimed' =>
        'This travel was already claimed. Void the claiming export first.',
      'travel_too_many' => 'This shift already has the maximum 16 travel rows.',
      'nominated_participant_inactive' =>
        'The nominated participant is no longer active.',
      'travel_item_not_claimable' ||
      'travel_item_unit_not_exportable' ||
      'travel_equal_mixed_registration_groups' ||
      'travel_registration_group_mismatch' =>
        failure.message,
      _ => failure.message,
    };
  }

  static String _formatQty(double value) {
    final fixed = value.toStringAsFixed(4);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
