import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/equal_fill_row.dart';

class ClientDetailSupportSection extends StatelessWidget {
  const ClientDetailSupportSection({
    super.key,
    required this.hasOngoing,
    required this.canManage,
    required this.supportItemCode,
    required this.supportItemName,
    required this.onStartOngoing,
    required this.onBookOne,
    required this.onOpenOngoing,
  });

  final bool hasOngoing;
  final bool canManage;
  final String? supportItemCode;
  final String? supportItemName;
  final VoidCallback onStartOngoing;
  final VoidCallback onBookOne;
  final VoidCallback onOpenOngoing;

  bool get _showStandingSupportItem {
    final code = supportItemCode?.trim();
    final name = supportItemName?.trim();
    return code != null &&
        code.isNotEmpty &&
        name != null &&
        name.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final start = canManage && !hasOngoing
        ? ElevatedButton.icon(
            onPressed: onStartOngoing,
            icon: const Icon(Icons.event_repeat_outlined),
            label: const Text('Start ongoing support'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
          )
        : null;
    final book = canManage
        ? ElevatedButton.icon(
            onPressed: onBookOne,
            icon: const Icon(Icons.event_outlined),
            label: const Text('Book one session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
          )
        : null;
    final open = hasOngoing
        ? OutlinedButton(
            onPressed: onOpenOngoing,
            child: const Text('Open support'),
          )
        : null;
    final rowChildren = <Widget>[
      if (start != null) start,
      if (book != null) book,
      if (open != null) open,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Support',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (rowChildren.isNotEmpty) EqualFillRow(children: rowChildren),
        if (_showStandingSupportItem) ...[
          const SizedBox(height: 12),
          Text(
            supportItemName!.trim(),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            supportItemCode!.trim(),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
