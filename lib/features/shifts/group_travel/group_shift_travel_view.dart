import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../features/billing/data/ndis_catalogue_filter_prefs.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../data/models/shift_travel_models.dart';
import 'group_shift_travel_controller.dart';

class GroupShiftTravelView extends GetView<GroupShiftTravelController> {
  const GroupShiftTravelView({super.key, this.catalogueFilterPrefs});

  /// Test seam so widget tests can avoid GetStorage.
  final NdisCatalogueFilterPrefs? catalogueFilterPrefs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit travel' : 'Add travel'),
        leading: IconButton(
          icon: const BackButtonIcon(),
          tooltip: 'Back to shift',
          onPressed: controller.cancel,
        ),
      ),
      body: Obx(() {
        final error = controller.errorMessage.value;
        // Register draft + helper so Item/Split rebuild when they change.
        controller.draft.value;
        controller.itemClearedHelper.value;
        controller.mmmCategory.value;
        final isSaving = controller.isSaving.value;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _StepIndicator(step: controller.step.value),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (error != null) ...[
                          _ErrorBox(error),
                          const SizedBox(height: 12),
                        ],
                        switch (controller.step.value) {
                          GroupShiftTravelController.itemStep => _ItemStep(
                            controller: controller,
                            catalogueFilterPrefs: catalogueFilterPrefs,
                          ),
                          GroupShiftTravelController.splitStep => _SplitStep(
                            controller: controller,
                          ),
                          _ => _ReviewStep(controller: controller),
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (controller.step.value == GroupShiftTravelController.reviewStep)
              FormStickyActions(
                onCancel: isSaving ? null : controller.previousStep,
                cancelLabel: 'Back',
                primaryLabel: 'Save',
                onPrimary: isSaving ? null : controller.save,
                isLoading: isSaving,
              )
            else
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: PageContent(
                    width: PageContentWidth.narrow,
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed:
                              isSaving
                                  ? null
                                  : controller.step.value == 0
                                  ? controller.cancel
                                  : controller.previousStep,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(88, 44),
                          ),
                          child: Text(
                            controller.step.value == 0 ? 'Cancel' : 'Back',
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: isSaving ? null : controller.nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            minimumSize: const Size(88, 44),
                          ),
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (
          var i = 0;
          i < GroupShiftTravelController.stepLabels.length;
          i++
        ) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  GroupShiftTravelController.stepLabels[i],
                  style: TextStyle(
                    color: i == step ? AppColors.textDark : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: i == step ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemStep extends StatefulWidget {
  const _ItemStep({required this.controller, this.catalogueFilterPrefs});

  final GroupShiftTravelController controller;
  final NdisCatalogueFilterPrefs? catalogueFilterPrefs;

  @override
  State<_ItemStep> createState() => _ItemStepState();
}

class _ItemStepState extends State<_ItemStep> {
  late final TextEditingController _quantity;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: widget.controller.draft.value.quantity ?? '',
    );
    _notes = TextEditingController(
      text: widget.controller.draft.value.notes ?? '',
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.controller.draft.value;
    final isLabour = draft.isLabour;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.controller.canChangeClaimKind) ...[
          Text('Claim type', style: Get.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<TravelClaimKind>(
            segments: const [
              ButtonSegment(
                value: TravelClaimKind.nonLabour,
                label: Text(GroupShiftTravelController.vehicleSectionTitle),
                icon: Icon(Icons.directions_car_outlined, size: 18),
              ),
              ButtonSegment(
                value: TravelClaimKind.labour,
                label: Text(GroupShiftTravelController.workerTimeSectionTitle),
                icon: Icon(Icons.timer_outlined, size: 18),
              ),
            ],
            selected: {draft.claimKind},
            onSelectionChanged: (selection) {
              widget.controller.setClaimKind(selection.first);
              _quantity.clear();
            },
          ),
          const SizedBox(height: 20),
        ],
        if (isLabour)
          _LabourItemFields(
            controller: widget.controller,
            quantityController: _quantity,
            notesController: _notes,
          )
        else
          _KmItemFields(
            controller: widget.controller,
            catalogueFilterPrefs: widget.catalogueFilterPrefs,
            quantityController: _quantity,
            notesController: _notes,
          ),
      ],
    );
  }
}

class _KmItemFields extends StatelessWidget {
  const _KmItemFields({
    required this.controller,
    required this.quantityController,
    required this.notesController,
    this.catalogueFilterPrefs,
  });

  final GroupShiftTravelController controller;
  final NdisCatalogueFilterPrefs? catalogueFilterPrefs;
  final TextEditingController quantityController;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    final draft = controller.draft.value;
    final clearedHelper = controller.itemClearedHelper.value;
    final showMixedEqual = controller.hasMixedEqualRegistrationGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          GroupShiftTravelController.vehicleSectionTitle,
          style: Get.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (showMixedEqual) ...[
          _ErrorBox(GroupShiftTravelController.mixedEqualErrorMessage),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.switchToNominatedSplit,
              child: const Text('Switch to Nominated split'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        NdisSupportItemPicker(
          key: ValueKey(controller.travelPickerKey),
          supportItemCode: draft.supportItemCode,
          supportItemName: draft.supportItemName,
          allowedUnits: const {'E'},
          itemPredicate: controller.travelCataloguePredicate,
          filterPrefs: catalogueFilterPrefs,
          labelText: 'Travel support item',
          onChanged: ({required supportItemCode, required supportItemName}) {
            controller.setItem(
              supportItemCode: supportItemCode,
              supportItemName: supportItemName,
            );
          },
        ),
        if (!controller.hasTravelAnchors) ...[
          const SizedBox(height: 8),
          const Text(
            GroupShiftTravelController.noAnchorsHelperMessage,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
        if (clearedHelper != null) ...[
          const SizedBox(height: 8),
          Text(
            clearedHelper,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: 'Kilometres',
            hintText: 'e.g. 12.5',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: controller.setQuantity,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          maxLength: 500,
          maxLines: 3,
          onChanged: controller.setNotes,
        ),
      ],
    );
  }
}

class _LabourItemFields extends StatelessWidget {
  const _LabourItemFields({
    required this.controller,
    required this.quantityController,
    required this.notesController,
  });

  final GroupShiftTravelController controller;
  final TextEditingController quantityController;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          GroupShiftTravelController.workerTimeSectionTitle,
          style: Get.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Billed as Provider Travel from each participant’s published hourly item.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Support item',
            border: OutlineInputBorder(),
          ),
          child: Text(
            controller.labourSupportItemLabel,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        if (!controller.hasTravelAnchors) ...[
          const SizedBox(height: 8),
          const Text(
            GroupShiftTravelController.labourNoSnapshotHelper,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
        if (controller.showTherapyHalfRateNote) ...[
          const SizedBox(height: 8),
          const Text(
            GroupShiftTravelController.therapyHalfRateNote,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'e.g. 45',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: controller.setQuantity,
        ),
        if (controller.showOverCapBanner) ...[
          const SizedBox(height: 12),
          _OverCapBanner(
            title: GroupShiftTravelController.overCapBannerTitle,
            body: controller.overCapBannerBody(),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          maxLength: 500,
          maxLines: 3,
          onChanged: controller.setNotes,
        ),
      ],
    );
  }
}

class _OverCapBanner extends StatelessWidget {
  const _OverCapBanner({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '$title. $body',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: AppColors.error)),
          ],
        ),
      ),
    );
  }
}

class _SplitStep extends StatelessWidget {
  const _SplitStep({required this.controller});

  final GroupShiftTravelController controller;

  @override
  Widget build(BuildContext context) {
    final draft = controller.draft.value;
    final clearedHelper = controller.itemClearedHelper.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Split', style: Get.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (controller.hasMixedEqualRegistrationGroups) ...[
          _ErrorBox(GroupShiftTravelController.mixedEqualErrorMessage),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.switchToNominatedSplit,
              child: const Text('Switch to Nominated split'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        RadioGroup<TravelApportionmentMode>(
          groupValue: draft.apportionmentMode,
          onChanged: (value) {
            if (value != null) controller.setMode(value);
          },
          child: const Column(
            children: [
              RadioListTile<TravelApportionmentMode>(
                contentPadding: EdgeInsets.zero,
                title: Text('Equal'),
                subtitle: Text('Share quantity across active participants'),
                value: TravelApportionmentMode.equal,
              ),
              RadioListTile<TravelApportionmentMode>(
                contentPadding: EdgeInsets.zero,
                title: Text('Nominated'),
                subtitle: Text('Assign the full quantity to one participant'),
                value: TravelApportionmentMode.nominated,
              ),
            ],
          ),
        ),
        if (draft.apportionmentMode == TravelApportionmentMode.nominated) ...[
          const Divider(height: 24),
          Text('Participant', style: Get.textTheme.titleSmall),
          RadioGroup<String>(
            groupValue: draft.nominatedParticipantId,
            onChanged: controller.setNominee,
            child: Column(
              children: [
                for (final participant in controller.active)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      participant.participantName ?? participant.participantId,
                    ),
                    value: participant.id,
                  ),
              ],
            ),
          ),
        ],
        if (clearedHelper != null) ...[
          const SizedBox(height: 12),
          Text(
            clearedHelper,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.controller});

  final GroupShiftTravelController controller;

  @override
  Widget build(BuildContext context) {
    final draft = controller.draft.value;
    final shares = controller.apportionedQuantities;
    final isLabour = draft.isLabour;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.showOverCapBanner) ...[
          _OverCapBanner(
            title: GroupShiftTravelController.overCapBannerTitle,
            body: controller.overCapBannerBody(),
          ),
          const SizedBox(height: 16),
        ],
        _ReviewRow(
          label: 'Type',
          value:
              isLabour
                  ? GroupShiftTravelController.workerTimeSectionTitle
                  : GroupShiftTravelController.vehicleSectionTitle,
        ),
        _ReviewRow(
          label: 'Item',
          value:
              isLabour
                  ? controller.labourSupportItemLabel
                  : (draft.supportItemCode ?? '—'),
        ),
        _ReviewRow(
          label: isLabour ? 'Minutes' : 'Kilometres',
          value:
              draft.quantity == null
                  ? '—'
                  : isLabour
                  ? '${draft.quantity} min'
                  : '${draft.quantity} km',
        ),
        _ReviewRow(
          label: 'Split',
          value:
              draft.apportionmentMode == TravelApportionmentMode.equal
                  ? 'Equal'
                  : 'Nominated',
        ),
        const SizedBox(height: 12),
        Text(
          isLabour ? 'Minutes by participant' : 'Quantity by participant',
          style: Get.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        for (final participant in controller.active)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              participant.participantName ?? participant.participantId,
            ),
            trailing: Text(
              '${GroupShiftTravelController.formatShare(
                shares[participant.id] ?? 0,
              )}${isLabour ? ' min' : ''}',
            ),
          ),
        if (draft.notes?.trim().isNotEmpty == true)
          _ReviewRow(label: 'Notes', value: draft.notes!.trim()),
        if (controller.showTherapyHalfRateNote) ...[
          const SizedBox(height: 8),
          const Text(
            GroupShiftTravelController.therapyHalfRateNote,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Travel is claimed once, on the first invoice export. To change '
          'claimed travel, void the claiming export first.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}
