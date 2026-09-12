import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../data/models/shift_travel_models.dart';
import 'group_shift_travel_controller.dart';

class GroupShiftTravelView extends GetView<GroupShiftTravelController> {
  const GroupShiftTravelView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit travel' : 'Add travel'),
      ),
      body: Obx(() {
        final error = controller.errorMessage.value;
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
                onCancel:
                    controller.isSaving.value ? null : controller.previousStep,
                primaryLabel: 'Save',
                onPrimary: controller.isSaving.value ? null : controller.save,
                isLoading: controller.isSaving.value,
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
                              controller.isSaving.value
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
                          onPressed:
                              controller.isSaving.value
                                  ? null
                                  : controller.nextStep,
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
  const _ItemStep({required this.controller});

  final GroupShiftTravelController controller;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NdisSupportItemPicker(
          supportItemCode: draft.supportItemCode,
          supportItemName: draft.supportItemName,
          allowedUnits: const {'E', 'H'},
          labelText: 'Travel support item',
          onChanged: ({required supportItemCode, required supportItemName}) {
            widget.controller.setItem(
              supportItemCode: supportItemCode,
              supportItemName: supportItemName,
            );
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _quantity,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            hintText: 'e.g. 10',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: widget.controller.setQuantity,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          maxLength: 500,
          maxLines: 3,
          onChanged: widget.controller.setNotes,
        ),
      ],
    );
  }
}

class _SplitStep extends StatelessWidget {
  const _SplitStep({required this.controller});

  final GroupShiftTravelController controller;

  @override
  Widget build(BuildContext context) {
    final draft = controller.draft.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Split', style: Get.textTheme.titleMedium),
        const SizedBox(height: 8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewRow(label: 'Item', value: draft.supportItemCode ?? '—'),
        _ReviewRow(label: 'Total quantity', value: draft.quantity ?? '—'),
        _ReviewRow(
          label: 'Split',
          value:
              draft.apportionmentMode == TravelApportionmentMode.equal
                  ? 'Equal'
                  : 'Nominated',
        ),
        const SizedBox(height: 12),
        Text('Quantity by participant', style: Get.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final participant in controller.active)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              participant.participantName ?? participant.participantId,
            ),
            trailing: Text(
              GroupShiftTravelController.formatShare(
                shares[participant.id] ?? 0,
              ),
            ),
          ),
        if (draft.notes?.trim().isNotEmpty == true)
          _ReviewRow(label: 'Notes', value: draft.notes!.trim()),
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
