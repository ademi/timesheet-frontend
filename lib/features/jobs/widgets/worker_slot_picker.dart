import 'package:flutter/material.dart';

class WorkerSlotEngagement {
  const WorkerSlotEngagement({
    required this.contractorId,
    required this.displayName,
  });

  final String contractorId;
  final String displayName;
}

/// Shared multi-slot worker dropdowns (Unfilled + engagements).
///
/// [onChanged] may return false to reject a pick (e.g. duplicate); the field
/// keeps the prior [slots] value from the parent.
class WorkerSlotPicker extends StatelessWidget {
  const WorkerSlotPicker({
    super.key,
    required this.slots,
    required this.engagements,
    required this.onChanged,
    this.trailingForSlot,
    this.enabled = true,
  });

  /// Selected contractor ids per slot; null = Unfilled.
  final List<String?> slots;
  final List<WorkerSlotEngagement> engagements;

  /// Returns false to reject the change (parent keeps prior selection).
  final bool Function(int index, String? contractorId) onChanged;

  /// Optional trailing beside each engagement name (e.g. Free/Busy label).
  final Widget? Function(int index, String? contractorId)? trailingForSlot;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final workers = [
      for (final e in engagements)
        if (seen.add(e.contractorId)) e,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slots.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('assign-slot-$i'),
            value: slots[i],
            isExpanded: true,
            decoration: InputDecoration(
              labelText: slots.length == 1
                  ? 'Worker (optional)'
                  : 'Worker ${i + 1} (optional)',
              border: const OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Unfilled'),
              ),
              for (final engagement in workers)
                DropdownMenuItem<String?>(
                  value: engagement.contractorId,
                  child: _EngagementItem(
                    displayName: engagement.displayName,
                    trailing: trailingForSlot?.call(i, engagement.contractorId),
                  ),
                ),
              if (slots[i] != null && !seen.contains(slots[i]))
                DropdownMenuItem<String?>(
                  value: slots[i],
                  child: Text(slots[i]!),
                ),
            ],
            onChanged: enabled
                ? (value) {
                    onChanged(i, value);
                  }
                : null,
          ),
        ],
      ],
    );
  }
}

class _EngagementItem extends StatelessWidget {
  const _EngagementItem({
    required this.displayName,
    this.trailing,
  });

  final String displayName;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (trailing == null) {
      return Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Row(
      children: [
        Flexible(
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing!,
      ],
    );
  }
}
