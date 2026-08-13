import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Support',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (canManage && !hasOngoing) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onStartOngoing,
              icon: const Icon(Icons.event_repeat_outlined),
              label: const Text('Start ongoing support'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start ongoing support first.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
        if (hasOngoing)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canManage)
                ElevatedButton.icon(
                  onPressed: onBookOne,
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Book one session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                  ),
                ),
              OutlinedButton(
                onPressed: onOpenOngoing,
                child: const Text('Open support'),
              ),
            ],
          ),
      ],
    );
  }
}
