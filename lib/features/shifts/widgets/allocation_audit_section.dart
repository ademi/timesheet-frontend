import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../data/models/shift_participant_models.dart';

class AllocationAuditSection extends StatelessWidget {
  const AllocationAuditSection({
    super.key,
    required this.changes,
    required this.participantNames,
    required this.isLoading,
  });

  final List<AllocationChangeLogOut> changes;
  final Map<String, String> participantNames;
  final bool isLoading;

  String _fmt(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _changeLabel(AllocationChangeLogOut change) {
    return switch (change.changeType) {
      'participant_added' => 'Participant added',
      'participant_removed' => 'Participant removed',
      'allocation_updated' => 'Allocation updated',
      _ => change.changeType.replaceAll('_', ' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<AllocationChangeLogOut>.of(changes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Allocation history',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (isLoading && sorted.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (sorted.isEmpty)
          const Text('No allocation changes yet.')
        else
          for (final change in sorted)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${_changeLabel(change)} · '
                '${participantNames[change.participantId] ?? 'Participant'}',
              ),
              subtitle: Text(
                '${change.changeReason}\n${_fmt(change.createdAt)}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              isThreeLine: true,
            ),
      ],
    );
  }
}
