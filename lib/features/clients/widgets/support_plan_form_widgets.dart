import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';

String supportPlanFieldLabel(String key) => key.replaceAll('_', ' ');

Widget supportPlanField(
  TextEditingController ctrl,
  String label, {
  int maxLines = 1,
}) {
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

class SupportPlanSectionTitle extends StatelessWidget {
  const SupportPlanSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    );
  }
}

class SupportPlanClientBanner extends StatelessWidget {
  const SupportPlanClientBanner({super.key, required this.name, this.ndis});

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

class SupportPlanRepairBanner extends StatelessWidget {
  const SupportPlanRepairBanner({super.key});

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

class SupportPlanGoalCard extends StatelessWidget {
  const SupportPlanGoalCard({
    super.key,
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
          supportPlanField(ndisGoal, 'NDIS goal', maxLines: 2),
          const SizedBox(height: 12),
          supportPlanField(strategy, 'Strategy', maxLines: 2),
          const SizedBox(height: 12),
          supportPlanField(measure, 'Measure', maxLines: 2),
          const SizedBox(height: 12),
          supportPlanField(workerInstructions, 'Worker instructions', maxLines: 2),
        ],
      ),
    );
  }
}

Future<void> pickSupportPlanNextReview({
  required BuildContext context,
  required String? currentValue,
  required void Function(String isoDate) onPicked,
}) async {
  final now = DateTime.now();
  final initial = DateTime.tryParse(currentValue ?? '') ?? now;
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
  onPicked('$y-$m-$d');
}
