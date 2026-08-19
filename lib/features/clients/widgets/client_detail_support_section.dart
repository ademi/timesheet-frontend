import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/equal_fill_row.dart';

class ClientDetailSupportSection extends StatelessWidget {
  const ClientDetailSupportSection({
    super.key,
    required this.hasOngoing,
    required this.canManage,
    required this.onStartOngoing,
    required this.onBookOne,
    required this.onOpenOngoing,
  });

  final bool hasOngoing;
  final bool canManage;
  final VoidCallback onStartOngoing;
  final VoidCallback onBookOne;
  final VoidCallback onOpenOngoing;

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
      ],
    );
  }
}
