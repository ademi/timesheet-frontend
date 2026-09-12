import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../utils/group_participant_draft.dart';

/// Group-level Capacity % | Time windows segment (D5 / D12).
class GroupAllocationStrategySegment extends StatelessWidget {
  const GroupAllocationStrategySegment({
    super.key,
    required this.strategy,
    required this.onChanged,
    this.enabled = true,
  });

  final String strategy;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Allocation strategy',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _Seg(
              label: 'Capacity %',
              selected: strategy == GroupAllocationStrategy.percentage,
              enabled: enabled,
              onTap:
                  () => onChanged(GroupAllocationStrategy.percentage),
            ),
            _Seg(
              label: 'Time windows',
              selected: strategy == GroupAllocationStrategy.timeBased,
              enabled: enabled,
              onTap: () => onChanged(GroupAllocationStrategy.timeBased),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      selected
                          ? AppColors.onPrimary
                          : AppColors.textDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
