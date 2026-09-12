import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../data/models/shift_models.dart';
import '../utils/publish_estimate_math.dart';
import 'group_shift_publish_controller.dart';

class GroupShiftPublishView extends GetView<GroupShiftPublishController> {
  const GroupShiftPublishView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() {
          switch (controller.step.value) {
            case GroupShiftPublishController.itemStep:
              return const Text('Default support item');
            case GroupShiftPublishController.peopleStep:
              return const Text('People');
            case GroupShiftPublishController.stayStep:
              return const Text('Accommodation');
            default:
              return const Text('Review & publish');
          }
        }),
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.catalogueNationalByCode.isEmpty &&
            (controller.draft.value.supportItemCode ?? '').isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value;
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
                        if (err != null) ...[
                          _ErrorBox(err),
                          const SizedBox(height: 12),
                        ],
                        switch (controller.step.value) {
                          GroupShiftPublishController.itemStep =>
                            _ItemStep(controller: controller),
                          GroupShiftPublishController.peopleStep =>
                            _PeopleStep(controller: controller),
                          GroupShiftPublishController.stayStep =>
                            _StayStep(controller: controller),
                          _ => _ReviewStep(controller: controller),
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (controller.step.value == GroupShiftPublishController.maxStep)
              FormStickyActions(
                onCancel: controller.isSaving.value ? null : controller.cancel,
                primaryLabel: 'Publish',
                onPrimary:
                    controller.isSaving.value ? null : controller.publish,
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
                        if (controller.step.value > 0)
                          OutlinedButton(
                            onPressed:
                                controller.isSaving.value
                                    ? null
                                    : controller.previousStep,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(88, 48),
                            ),
                            child: const Text('Back'),
                          )
                        else
                          OutlinedButton(
                            onPressed:
                                controller.isSaving.value
                                    ? null
                                    : controller.cancel,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(88, 48),
                            ),
                            child: const Text('Cancel'),
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
                            minimumSize: const Size(88, 48),
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
    const labels = GroupShiftPublishController.stepLabels;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
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
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: i == step ? AppColors.textDark : AppColors.textMuted,
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _ItemStep extends StatelessWidget {
  const _ItemStep({required this.controller});
  final GroupShiftPublishController controller;

  @override
  Widget build(BuildContext context) {
    final d = controller.draft.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Applies to all participants unless overridden.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        NdisSupportItemPicker(
          supportItemCode: d.supportItemCode,
          supportItemName: d.supportItemName,
          labelText: 'Default support item',
          onChanged: ({
            required supportItemCode,
            required supportItemName,
          }) {
            controller.setDefaultItem(
              supportItemCode: supportItemCode,
              supportItemName: supportItemName,
            );
          },
        ),
      ],
    );
  }
}

class _PeopleStep extends StatelessWidget {
  const _PeopleStep({required this.controller});
  final GroupShiftPublishController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Use the default item, or set a custom item / rate per person.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        for (final p in active) ...[
          _ParticipantRow(controller: controller, participant: p),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.controller,
    required this.participant,
  });

  final GroupShiftPublishController controller;
  final ShiftParticipantOut participant;

  @override
  Widget build(BuildContext context) {
    final name = participant.participantName ?? participant.participantId;
    final custom = controller.draft.value.hasCustom(participant.participantId);
    final caption = controller.customCaption(participant.participantId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Get.textTheme.titleSmall),
                Text(
                  caption,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => controller.openCustomOverride(participant),
            style: TextButton.styleFrom(
              minimumSize: const Size(88, 44),
              foregroundColor: AppColors.primary,
            ),
            child: Text(custom ? 'Edit' : 'Custom…'),
          ),
          if (custom)
            TextButton(
              onPressed: () =>
                  controller.clearOverride(participant.participantId),
              style: TextButton.styleFrom(
                minimumSize: const Size(72, 44),
                foregroundColor: AppColors.textMuted,
              ),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

class _StayStep extends StatefulWidget {
  const _StayStep({required this.controller});
  final GroupShiftPublishController controller;

  @override
  State<_StayStep> createState() => _StayStepState();
}

class _StayStepState extends State<_StayStep> {
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: widget.controller.draft.value.accommodationQuantity ?? '',
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final d = c.draft.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Optional unbundled STA / respite day item. Off by default — '
          'never legacy bundled ratio SKUs.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include accommodation'),
          value: d.accommodationEnabled,
          activeThumbColor: AppColors.primary,
          onChanged: (enabled) {
            c.setAccommodationEnabled(enabled);
            if (enabled) {
              _qtyCtrl.text = c.draft.value.accommodationQuantity ?? '1';
            } else {
              _qtyCtrl.clear();
            }
          },
        ),
        if (d.accommodationEnabled) ...[
          const SizedBox(height: 8),
          NdisSupportItemPicker(
            supportItemCode: d.accommodationSupportItemCode,
            supportItemName: d.accommodationSupportItemName,
            labelText: 'Accommodation support item',
            onChanged: ({
              required supportItemCode,
              required supportItemName,
            }) {
              c.setAccommodationItem(
                supportItemCode: supportItemCode,
                supportItemName: supportItemName,
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            decoration: const InputDecoration(
              labelText: 'Quantity (days)',
              hintText: 'e.g. 1',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: c.setAccommodationQuantity,
          ),
        ],
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.controller});
  final GroupShiftPublishController controller;

  @override
  Widget build(BuildContext context) {
    final d = controller.draft.value;
    final estimates = controller.estimates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewBlock(
          title: 'Default item',
          child: Text(d.supportItemCode ?? '—'),
        ),
        _ReviewBlock(
          title: 'Participants',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in controller.active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${p.participantName ?? p.participantId} · '
                    '${controller.customCaption(p.participantId)} · '
                    '${controller.participantEstimateLabel(p.participantId)}',
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                'Estimates from catalogue ÷ N — not a tax invoice',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        _ReviewBlock(
          title: 'Accommodation',
          child: Text(
            d.accommodationEnabled
                ? '${d.accommodationSupportItemCode ?? '—'} · '
                    'qty ${d.accommodationQuantity ?? '—'}'
                : 'None',
          ),
        ),
        if (estimates.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Group support total '
            '${formatEstimateMoney(estimates.fold<double>(0, (a, e) => a + e.supportAmount))} · '
            'Stay '
            '${formatEstimateMoney(estimates.fold<double>(0, (a, e) => a + e.accommodationAmount))}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.02,
            ),
          ),
          const SizedBox(height: 4),
          child,
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}
