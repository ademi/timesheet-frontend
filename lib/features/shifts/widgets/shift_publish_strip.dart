import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../data/models/shift_models.dart';
import '../utils/allocation_math.dart';

class ShiftPublishStrip extends StatelessWidget {
  const ShiftPublishStrip({
    super.key,
    required this.shift,
    required this.canManage,
    required this.canPublish,
    required this.isSaving,
    required this.showDraftCapacityHint,
    required this.onPublish,
    required this.onDismissHint,
  });

  final ShiftOut shift;
  final bool canManage;
  final bool canPublish;
  final bool isSaving;
  final bool showDraftCapacityHint;
  final Future<void> Function() onPublish;
  final VoidCallback onDismissHint;

  String _formatPercentage(double value) =>
      value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(1);

  String? get _disabledReason {
    final active = activeParticipants(shift.participants);
    if (active.isEmpty) return 'Add at least one participant to publish.';
    final strategy = active.first.allocationStrategy;
    if (strategy == 'percentage') {
      return 'Active percentages must total 100% '
          '(now ${_formatPercentage(sumActivePercentage(active))}%).';
    }
    if (strategy == 'time_based') {
      return 'Each participant needs at least one time window.';
    }
    return 'All participants must use the same allocation strategy.';
  }

  String get _statusLabel {
    final status = shift.status;
    return status.isEmpty
        ? 'Unknown'
        : '${status[0].toUpperCase()}${status.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = shift.status == 'draft';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _statusLabel,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isDraft && canManage)
                SizedBox(
                  width: 132,
                  child: AsyncElevatedButton(
                    onPressed: canPublish ? onPublish : null,
                    isLoading: isSaving,
                    child: const Text('Publish'),
                  ),
                ),
            ],
          ),
        ),
        if (isDraft && canManage && !canPublish) ...[
          const SizedBox(height: 6),
          Text(
            _disabledReason!,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
        if (showDraftCapacityHint && isDraft) ...[
          const SizedBox(height: 8),
          MaterialBanner(
            content: const Text(
              'Draft saved. Adjust capacity to 100% to publish.',
            ),
            actions: [
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismissHint,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
