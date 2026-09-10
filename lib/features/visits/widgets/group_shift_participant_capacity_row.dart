import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';

class GroupShiftParticipantCapacityRow extends StatelessWidget {
  const GroupShiftParticipantCapacityRow({
    super.key,
    required this.clientName,
    required this.capacityController,
    required this.isHost,
    required this.onCapacityChanged,
    required this.onRemove,
  });

  final String clientName;
  final TextEditingController capacityController;
  final bool isHost;
  final ValueChanged<String> onCapacityChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                isHost ? '$clientName (host)' : clientName,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 132,
            child: TextFormField(
              key: Key('group-shift-capacity-${capacityController.hashCode}'),
              controller: capacityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              scrollPadding: const EdgeInsets.only(bottom: 140),
              decoration: const InputDecoration(
                labelText: 'Capacity (%)',
                border: OutlineInputBorder(),
              ),
              onChanged: onCapacityChanged,
              validator: (value) {
                final capacity = double.tryParse(value?.trim() ?? '');
                if (capacity == null) return 'Enter a number';
                if (capacity <= 0 || capacity > 100) return 'Use 1–100';
                return null;
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: isHost ? 'Host cannot be removed' : 'Remove $clientName',
            onPressed: isHost ? null : onRemove,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}
