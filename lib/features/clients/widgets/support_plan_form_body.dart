import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/other_text_field.dart';
import '../controllers/support_plan_controller.dart';
import '../utils/support_plan_keys.dart';

/// Support plan fields only — no Scaffold, no sticky footer, no [Get.back].
class SupportPlanFormBody extends StatelessWidget {
  const SupportPlanFormBody({super.key, required this.controller});

  final SupportPlanController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.displayName.isNotEmpty)
          _ClientBanner(
            name: controller.displayName,
            ndis: controller.displayNdis,
          ),
        Obx(() {
          if (!controller.needsBodyRepair.value) {
            return const SizedBox.shrink();
          }
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _RepairBanner(),
          );
        }),
        const SizedBox(height: 16),
        const _SectionTitle('Disability & health'),
        const SizedBox(height: 12),
        _field(controller.primaryDisabilityCtrl, 'Primary disability'),
        const SizedBox(height: 12),
        _field(
          controller.secondaryConditionsCtrl,
          'Secondary conditions',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _field(
          controller.functionalImpactCtrl,
          'Functional impact summary',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        const Text(
          'Functional limitations',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key
                  in SupportPlanController.functionalLimitationOptions)
                FilterChip(
                  label: Text(_label(key)),
                  selected: controller.functionalLimitations.contains(key),
                  onSelected: (_) => controller.toggleLimitation(key),
                ),
            ],
          ),
        ),
        Obx(
          () => OtherTextField(
            isOther: controller.functionalLimitations.contains(
              SupportPlanKeys.limitationOther,
            ),
            controller: controller.limitationOtherCtrl,
            label: 'Functional limitation (other)',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Communication methods',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in SupportPlanController.communicationOptions)
                FilterChip(
                  label: Text(_label(key)),
                  selected: controller.communicationMethods.contains(key),
                  onSelected: (_) => controller.toggleCommunication(key),
                ),
            ],
          ),
        ),
        Obx(
          () => OtherTextField(
            isOther: controller.communicationMethods.contains(
              SupportPlanKeys.commOther,
            ),
            controller: controller.commOtherCtrl,
            label: 'Communication method (other)',
          ),
        ),
        const SizedBox(height: 12),
        _field(controller.mobilityNeedsCtrl, 'Mobility needs', maxLines: 2),
        const SizedBox(height: 12),
        _field(
          controller.medicationScheduleCtrl,
          'Medication schedule',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _field(controller.gpNameCtrl, 'GP name')),
            const SizedBox(width: 12),
            Expanded(child: _field(controller.gpPhoneCtrl, 'GP phone')),
          ],
        ),
        const SizedBox(height: 8),
        Obx(
          () => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Behaviour support plan'),
            value: controller.behaviourSupportPlan.value,
            onChanged: (v) => controller.behaviourSupportPlan.value = v,
          ),
        ),
        Obx(
          () => DropdownButtonFormField<String>(
            value: controller.supportIntensity.value,
            decoration: const InputDecoration(
              labelText: 'Support intensity',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            items: [
              for (final v in SupportPlanController.intensityOptions)
                DropdownMenuItem(value: v, child: Text(_label(v))),
            ],
            onChanged: (v) {
              if (v != null) {
                controller.supportIntensity.value = v;
              }
            },
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Living'),
        const SizedBox(height: 12),
        Obx(
          () => DropdownButtonFormField<String>(
            value: controller.residenceType.value,
            decoration: const InputDecoration(
              labelText: 'Residence type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            items: [
              for (final v in SupportPlanController.residenceOptions)
                DropdownMenuItem(value: v, child: Text(_label(v))),
            ],
            onChanged: (v) {
              if (v != null) {
                controller.setResidenceType(v);
              }
            },
          ),
        ),
        Obx(
          () => OtherTextField(
            isOther: controller.residenceType.value ==
                SupportPlanKeys.residenceOther,
            controller: controller.residenceOtherCtrl,
            label: 'Residence type (other)',
          ),
        ),
        const SizedBox(height: 12),
        _field(
          controller.householdMembersCtrl,
          'Household members',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _field(
          controller.informalSupportsCtrl,
          'Informal supports',
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Goals'),
        const SizedBox(height: 12),
        Obx(() {
          final list = controller.goals;
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _GoalCard(
                  index: i,
                  ndisGoal: list[i].ndisGoal,
                  strategy: list[i].strategy,
                  measure: list[i].measure,
                  workerInstructions: list[i].workerInstructions,
                  onRemove: () => controller.removeGoal(i),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: list.length >= 20 ? null : controller.addGoal,
                  icon: const Icon(Icons.add),
                  label: const Text('Add goal'),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 24),
        const _SectionTitle('Service categories'),
        const SizedBox(height: 12),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in SupportPlanController.categoryOptions)
                FilterChip(
                  label: Text(_label(key)),
                  selected: controller.serviceCategories.contains(key),
                  onSelected: (_) => controller.toggleCategory(key),
                ),
            ],
          ),
        ),
        Obx(
          () => OtherTextField(
            isOther: controller.serviceCategories.contains(
              SupportPlanKeys.catOther,
            ),
            controller: controller.catOtherCtrl,
            label: 'Service category (other)',
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Preferences'),
        const SizedBox(height: 12),
        _field(
          controller.preferredSupportStyleCtrl,
          'Preferred support style',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _field(controller.routinesCtrl, 'Routines', maxLines: 2),
        const SizedBox(height: 12),
        _field(
          controller.interestsStrengthsCtrl,
          'Interests & strengths',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _field(controller.culturalNotesCtrl, 'Cultural notes', maxLines: 2),
        const SizedBox(height: 24),
        const _SectionTitle('Risk'),
        const SizedBox(height: 12),
        _field(controller.riskSummaryCtrl, 'Risk summary', maxLines: 2),
        const SizedBox(height: 12),
        _field(
          controller.behavioursOfConcernCtrl,
          'Behaviours of concern',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _field(controller.triggersCtrl, 'Triggers', maxLines: 2),
        const SizedBox(height: 12),
        _field(controller.deEscalationCtrl, 'De-escalation', maxLines: 2),
        const SizedBox(height: 12),
        _field(controller.crisisResponseCtrl, 'Crisis response', maxLines: 2),
        const SizedBox(height: 24),
        const _SectionTitle('Schedule'),
        const SizedBox(height: 12),
        _field(controller.serviceDaysCtrl, 'Service days'),
        const SizedBox(height: 12),
        _field(controller.typicalTimesCtrl, 'Typical times'),
        const SizedBox(height: 12),
        _field(
          controller.recommendedHoursCtrl,
          'Recommended hours note',
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Review'),
        const SizedBox(height: 12),
        Obx(
          () => Text(
            'Status: ${_label(controller.status.value)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final next = controller.nextReviewAt.value;
          return OutlinedButton.icon(
            onPressed: () => _pickNextReview(context),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              next == null || next.isEmpty
                  ? 'Set next review date'
                  : 'Next review: $next',
            ),
          );
        }),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _pickNextReview(BuildContext context) async {
    final now = DateTime.now();
    final initial = _parseDate(controller.nextReviewAt.value) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    controller.nextReviewAt.value = '$y-$m-$d';
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

String _label(String key) => key.replaceAll('_', ' ');

Widget _field(TextEditingController ctrl, String label, {int maxLines = 1}) {
  return TextField(
    controller: ctrl,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      alignLabelWithHint: maxLines > 1,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    );
  }
}

class _ClientBanner extends StatelessWidget {
  const _ClientBanner({required this.name, this.ndis});
  final String name;
  final String? ndis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          if (ndis != null && ndis!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'NDIS $ndis',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _RepairBanner extends StatelessWidget {
  const _RepairBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.openSlot),
      ),
      child: const Text(
        'Plan data invalid — review fields and Save to repair.',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.openSlot,
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.index,
    required this.ndisGoal,
    required this.strategy,
    required this.measure,
    required this.workerInstructions,
    required this.onRemove,
  });

  final int index;
  final TextEditingController ndisGoal;
  final TextEditingController strategy;
  final TextEditingController measure;
  final TextEditingController workerInstructions;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Goal ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove goal',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          _field(ndisGoal, 'NDIS goal', maxLines: 2),
          const SizedBox(height: 12),
          _field(strategy, 'Strategy', maxLines: 2),
          const SizedBox(height: 12),
          _field(measure, 'Measure', maxLines: 2),
          const SizedBox(height: 12),
          _field(workerInstructions, 'Worker instructions', maxLines: 2),
        ],
      ),
    );
  }
}
